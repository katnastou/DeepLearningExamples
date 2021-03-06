#! usr/bin/env python3
# -*- coding:utf-8 -*-
"""
Copyright 2018 The Google AI Language Team Authors.
BASED ON Google_BERT.
"""
from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import collections
import os, sys
import csv
import logging
import tensorflow as tf
import numpy as np

sys.path.append("/workspace/bert")

from biobert.conlleval import evaluate, report_notprint
import modeling
import optimization
import tokenization
import tf_metrics

import time
import horovod.tensorflow as hvd
from utils.utils import LogEvalRunHook, LogTrainRunHook

flags = tf.flags

FLAGS = flags.FLAGS

flags.DEFINE_string(
    "task_name", "NER", "The name of the task to train."
)

flags.DEFINE_string(
    "strategy", "mask",
    "The strategy for dealing with span of interest: mask or mark.",
)

flags.DEFINE_string(
    "input_file_type", "tsv", "The type of input file: tsv or csv supported"
)

flags.DEFINE_float(
    "keep_prob", 0.9,
    "The keep probability = 1-dropout")

flags.DEFINE_string(
    "data_dir", None,
    "The input datadir.",
)

flags.DEFINE_string(
    "output_dir", None,
    "The output directory where the model checkpoints will be written."
)

flags.DEFINE_string(
    "bert_config_file", None,
    "The config json file corresponding to the pre-trained BERT model."
)

flags.DEFINE_string(
    "vocab_file", None,
    "The vocabulary file that the BERT model was trained on.")

flags.DEFINE_string(
    "init_checkpoint", None,
    "Initial checkpoint (usually from a pre-trained BERT model)."
)

flags.DEFINE_bool(
    "do_lower_case", False,
    "Whether to lower case the input text."
)

flags.DEFINE_integer(
    "max_seq_length", 128,
    "The maximum total input sequence length after WordPiece tokenization."
)

flags.DEFINE_bool(
    "do_train", False,
    "Whether to run training."
)

flags.DEFINE_bool(
    "do_eval", False,
    "Whether to run eval on the dev set.")

flags.DEFINE_bool(
    "do_predict", False,
    "Whether to run the model in inference mode on the test set.")

flags.DEFINE_integer(
    "train_batch_size", 64,
    "Total batch size for training.")

flags.DEFINE_integer(
    "eval_batch_size", 16,
    "Total batch size for eval.")

flags.DEFINE_integer(
    "predict_batch_size", 16,
    "Total batch size for predict.")

flags.DEFINE_float(
    "learning_rate", 5e-6,
    "The initial learning rate for Adam.")

flags.DEFINE_float(
    "num_train_epochs", 10.0,
    "Total number of training epochs to perform.")

flags.DEFINE_float(
    "warmup_proportion", 0.1,
    "Proportion of training to perform linear learning rate warmup for. "
    "E.g., 0.1 = 10% of training.")

flags.DEFINE_integer(
    "save_checkpoints_steps", 1000,
    "How often to save the model checkpoint.")

flags.DEFINE_string(
    "replace_span_A", None,
    "Replace span text with given special token for entity A.")

flags.DEFINE_string(
    "replace_span_B", None,
    "Replace span text with given special token for entity B.")

flags.DEFINE_integer(
    "iterations_per_loop", 1000,
    "How many steps to make in each estimator call.")

tf.flags.DEFINE_string("master", None, "[Optional] TensorFlow master URL.")

flags.DEFINE_bool("horovod", False, "Whether to use Horovod for multi-gpu runs")
flags.DEFINE_bool("use_fp16", False, "Whether to use fp32 or fp16 arithmetic on GPU.")
flags.DEFINE_bool("use_xla", False, "Whether to enable XLA JIT compilation.")


class PaddingInputExample(object):
    """Fake example so the num input examples is a multiple of the batch size.
    When running eval/predict on the TPU, we need to pad the number of examples
    to be a multiple of the batch size, because the TPU requires a fixed batch
    size. The alternative is to drop the last batch, which is bad because it means
    the entire output data won't be generated.
    We use this class instead of `None` because treating `None` as padding
    battches could cause silent errors.
    """

class InputExample(object):
    """A single training/test example for simple sequence classification."""
    def __init__(self,guid,sent_start,entity1,text_between_ent_1_and_ent_2,entity2,sent_end,label=None):
        """Constructs a InputExample.
        Args:
          guid: Unique id for the example.
          text_a: string. The untokenized text of the first sequence. For single
            sequence tasks, only this sequence must be specified.
          label: (Optional) string. The label of the example. This should be
            specified for train and dev examples, but not for test examples.
        """
        self.guid = guid
        self.sent_start=sent_start
        self.entity1=entity1
        self.text_between_ent_1_and_ent_2=text_between_ent_1_and_ent_2
        self.entity2=entity2
        self.sent_end=sent_end
        self.label = label


class InputFeatures(object):
    """A single set of features of data."""

    def __init__(self, input_ids, input_mask, segment_ids, label_id, is_real_example=True):
        self.input_ids = input_ids
        self.input_mask = input_mask
        self.segment_ids = segment_ids
        self.label_id = label_id
        self.is_real_example = is_real_example


class DataProcessor(object):
    """Base class for data converters for sequence classification data sets."""

    def get_train_examples(self, data_dir, input_file_type):
        """Gets a collection of `InputExample`s for the train set."""
        raise NotImplementedError()

    def get_dev_examples(self, data_dir, input_file_type):
        """Gets a collection of `InputExample`s for the dev set."""
        raise NotImplementedError()

    def get_labels(self):
        """Gets the list of labels for this data set."""
        raise NotImplementedError()

    @classmethod
    def _read_tsv(cls, input_file, quotechar=None):
        """Reads a tab separated value file."""
        with tf.io.gfile.GFile(input_file, "r") as f:
            reader = csv.reader(f, delimiter="\t", quotechar=quotechar)
            lines = []
            for line in reader:
                lines.append(line)
            return lines
    
    @classmethod
    def _read_csv(cls, tsv_file, quotechar=None):
        with open(tsv_file, "rt") as tsv_handle:
            field_names = ['document_id', 'sentence_id', 'e1_id', 'e2_id', 
                        'text_before', 'e1_text', 'text_middle', 
                        'e2_text', 'text_right', 'label']
            tsv_reader = csv.reader(tsv_handle, delimiter=",", quotechar='"')
            #tsv_reader = csv.DictReader(tsv_handle, fieldnames=field_names)
            lines = []
            for line in tsv_reader:
                lines.append(line)
            return lines


class ConsensusProcessor(DataProcessor):
    def get_train_examples(self, data_dir, input_file_type):
        if(input_file_type=="tsv"):
            return self._create_examples(
                self._read_tsv(os.path.join(data_dir, "train.tsv")), "train")
        if(input_file_type=="csv"):
            data_file=os.path.join(data_dir, "train.tsv")
            return self._create_examples(
                self._read_csv(data_file), "train")
    def get_dev_examples(self, data_dir, input_file_type):
        if(input_file_type=="tsv"):
            return self._create_examples(
                self._read_tsv(os.path.join(data_dir,  "dev.tsv")), "dev")
        if(input_file_type=="csv"):
            return self._create_examples(
                self._read_csv(os.path.join(data_dir,  "devel.tsv")), "dev")
    def get_test_examples(self, data_dir, input_file_type):
        if(input_file_type=="tsv"):
            return self._create_examples(
                self._read_tsv(os.path.join(data_dir,  "test.tsv")), "test")
        if(input_file_type=="csv"):
            return self._create_examples(
                self._read_csv(os.path.join(data_dir,  "test.tsv")), "test")
    def get_labels(self):
        label_list = ["Not_a_complex","Complex_formation"]
        label_map = {l: i for i, l in enumerate(label_list)} 
        return label_list,label_map

    def _create_examples(self, lines, set_type):
        """Creates examples for the training and dev sets."""
        #the file now has 10 columns
        examples = []
        for (i, line) in enumerate(lines):
            guid = "%s-%s" % (set_type, i)
            sent_start = tokenization.convert_to_unicode(line[-6])
            entity1 = tokenization.convert_to_unicode(line[-5])
            text_between_ent_1_and_ent_2 = tokenization.convert_to_unicode(line[-4])
            entity2 = tokenization.convert_to_unicode(line[-3])
            sent_end = tokenization.convert_to_unicode(line[-2])
            label = tokenization.convert_to_unicode(line[-1])
            examples.append(
                InputExample(
                    guid=guid, 
                    sent_start=sent_start, 
                    entity1=entity1,
                    text_between_ent_1_and_ent_2=text_between_ent_1_and_ent_2,
                    entity2=entity2,
                    sent_end=sent_end,
                    label=label))
        return examples

def convert_single_example(ex_index, example, label_list,label_map, max_seq_length, tokenizer, replace_span_A, replace_span_B, strategy):
    if isinstance(example, PaddingInputExample):
        return InputFeatures(
            input_ids=[0] * max_seq_length,
            input_mask=[0] * max_seq_length,
            segment_ids=[0] * max_seq_length,
            label_id=0,
            is_real_example=False)
    #labels = sorted(list(setlabel_list))) 
    #label_map = {l: i for i, l in enumerate(label_list)}

    #code for text tokenization adapted from https://github.com/spyysalo/bert-span-classifier/
    sent_start_tok_bef = tokenizer.tokenize(example.sent_start)
    entity1_tok = tokenizer.tokenize(example.entity1)
    #text_between_ent_1_tok = tokenizer.tokenize(example.text_between_ent_1)
    #equiv1_tok = tokenizer.tokenize(example.equiv1)
    text_between_ent_1_and_ent_2_tok = tokenizer.tokenize(example.text_between_ent_1_and_ent_2)
    entity2_tok = tokenizer.tokenize(example.entity2)
    #text_between_ent_2_tok = tokenizer.tokenize(example.text_between_ent_2)
    #equiv2_tok = tokenizer.tokenize(example.equiv2)
    sent_end_tok = tokenizer.tokenize(example.sent_end)
    tokens_bef = ['[CLS]']
    center = int(max_seq_length/2)
    sent_start_tok=[]

    #replace  ##unused ##3 with unused3 before counting tokens in the start entity
    for i,v in enumerate(sent_start_tok_bef):
        if sent_start_tok_bef[i:i+2] == ["unused", "##3"]:
            sent_start_tok.append("[unused3]")
            #remove the ##3 token from the list of tokens
            sent_start_tok_bef.pop(i+1)
        else:
            sent_start_tok.append(sent_start_tok_bef[i])

    # I have removed sentences with more than 20 words in text_between_ent_1_and_ent_2_tok during preprocessing --> check if it needs more
    if (strategy == "mask"): #if we don't add marking tokens
        if (len(sent_start_tok+entity1_tok)+int(round(len(text_between_ent_1_and_ent_2_tok)/2))) > center-1:
            sent_start_tok = sent_start_tok[len(sent_start_tok+entity1_tok)+int(round(len(text_between_ent_1_and_ent_2_tok)/2))-(center-1):]
        else:
            sent_start_tok = ['[PAD]'] * ((center-1)-len(sent_start_tok+entity1_tok)+int(round(len(text_between_ent_1_and_ent_2_tok)/2))) + sent_start_tok
    else: #if we add the two tokens for marking we need to subtract 3 it's also the tokens left and right to mark the entities
        if (len(sent_start_tok+entity1_tok)+int(round(len(text_between_ent_1_and_ent_2_tok)/2))) > center-3:
            sent_start_tok = sent_start_tok[len(sent_start_tok+entity1_tok)+int(round(len(text_between_ent_1_and_ent_2_tok)/2))-(center-3):]
        else:
            sent_start_tok = ['[PAD]'] * ((center-3)-len(sent_start_tok+entity1_tok)+int(round(len(text_between_ent_1_and_ent_2_tok)/2))) + sent_start_tok
    
    tokens_bef.extend(sent_start_tok)
     
    if not replace_span_A:
        if (strategy == "mask"):
            tokens_bef.extend(entity1_tok)
        elif (strategy == "mark"):
            tokens_bef.append('[unused1]')
            tokens_bef.extend(entity1_tok)
            tokens_bef.append('[unused2]')
    else:
        if (strategy == "mask"):
            tokens_bef.append(replace_span_A)
        elif (strategy == "mark"):
            tokens_bef.append('[unused1]')
            tokens_bef.append(replace_span_A)
            tokens_bef.append('[unused2]')
    #tokens.extend(span_tok)
    #if an equiv entity exists
    #if example.text_between_ent_1:
    #    tokens_bef.extend(text_between_ent_1_tok)
    #    tokens_bef.extend(equiv1_tok)
    tokens_bef.extend(text_between_ent_1_and_ent_2_tok)
    
    #if not replace_span_B:
    #    tokens_bef.extend(entity2_tok)
    #else:
    #    tokens_bef.append(replace_span_B)
    if not replace_span_B:
        if (strategy == "mask"):
            tokens_bef.extend(entity2_tok)
        else:
            tokens_bef.append('[unused1]')
            tokens_bef.extend(entity2_tok)
            tokens_bef.append('[unused2]')
    else:
        if (strategy == "mask"):
            tokens_bef.append(replace_span_B)
        else:
            tokens_bef.append('[unused1]')
            tokens_bef.append(replace_span_B)
            tokens_bef.append('[unused2]')
    #if example.text_between_ent_2:
    #    tokens_bef.extend(text_between_ent_2_tok)
    #    tokens_bef.extend(equiv2_tok)

    tokens_bef.extend(sent_end_tok)
    tokens=[]
    #remove the rest of unused ##3 before expanding and extending
    for i,v in enumerate(tokens_bef):
        if tokens_bef[i:i+2] == ["unused", "##3"]:
            tokens.append("[unused3]")
            #remove the ##3 token from the list of tokens
            tokens_bef.pop(i+1)
        else:
            tokens.append(tokens_bef[i])

    if len(tokens) >= max_seq_length -1:
        tokens, chopped = tokens[:max_seq_length-1], tokens[max_seq_length-1:]
        #shows the chopped inputs, log files for 10M end up being 3gb because of that so I stopped logging that
        #logging.warning('chopping tokens to {}: {} ///// {}'.format(max_seq_length-1, ' '.join(tokens), ' '.join(chopped)))
    tokens.append('[SEP]')
    tokens.extend(['[PAD]'] * (max_seq_length-len(tokens)))
    segment_ids = []
    input_ids = tokenizer.convert_tokens_to_ids(tokens)
    input_mask = []
    for token in tokens:
        if token == "[PAD]":
            input_mask.append(0)
        else:
            input_mask.append(1)
    segment_ids = [0] * max_seq_length
    assert len(input_ids) == max_seq_length 
    assert len(input_mask) == max_seq_length
    assert len(segment_ids) == max_seq_length

    label_id = label_map[example.label]

    if ex_index < 5:
        tf.compat.v1.logging.info("*** Example ***")
        tf.compat.v1.logging.info("guid: %s" % (example.guid))
        tf.compat.v1.logging.info("tokens: %s" % " ".join(
            [tokenization.printable_text(x) for x in tokens]))
        tf.compat.v1.logging.info("input_ids: %s" % " ".join([str(x) for x in input_ids]))
        tf.compat.v1.logging.info("input_mask: %s" % " ".join([str(x) for x in input_mask]))
        tf.compat.v1.logging.info("segment_ids: %s" % " ".join([str(x) for x in segment_ids]))
        tf.compat.v1.logging.info("label: %s (id = %d)" % (example.label, label_id))
        tf.compat.v1.logging.info("strategy: %s" % (strategy)) 
    feature = InputFeatures(
        input_ids=input_ids,
        input_mask=input_mask,
        segment_ids=segment_ids,
        label_id=label_id,
        is_real_example=True
    )
    return feature

def _truncate_seq_pair(tokens_a, tokens_b, max_length):
    """Truncates a sequence pair in place to the maximum length."""

    # This is a simple heuristic which will always truncate the longer sequence
    # one token at a time. This makes more sense than truncating an equal percent
    # of tokens from each, since if one sequence is very short then each token
    # that's truncated likely contains more information than a longer sequence.
    while True:
        total_length = len(tokens_a) + len(tokens_b)
        if total_length <= max_length:
            break
        if len(tokens_a) > len(tokens_b):
            tokens_a.pop()
        else:
            tokens_b.pop()

def filed_based_convert_examples_to_features(examples, label_list, label_map, max_seq_length, tokenizer, output_file, replace_span_A, replace_span_B, strategy):
    writer = tf.python_io.TFRecordWriter(output_file)
    for (ex_index, example) in enumerate(examples):
        if ex_index % 20000 == 0:
            tf.compat.v1.logging.info("Writing example %d of %d" % (ex_index, len(examples)))
        feature = convert_single_example(ex_index, example, label_list, label_map, max_seq_length, tokenizer, replace_span_A, replace_span_B, strategy)

        def create_int_feature(values):
            f = tf.train.Feature(int64_list=tf.train.Int64List(value=list(values)))
            return f

        features = collections.OrderedDict()
        features["input_ids"] = create_int_feature(feature.input_ids)
        features["input_mask"] = create_int_feature(feature.input_mask)
        features["segment_ids"] = create_int_feature(feature.segment_ids)
        features["label_ids"] = create_int_feature([feature.label_id])
        features["is_real_example"] = create_int_feature(
            [int(feature.is_real_example)])
        tf_example = tf.train.Example(features=tf.train.Features(feature=features))
        writer.write(tf_example.SerializeToString())


def file_based_input_fn_builder(input_file, batch_size, seq_length, is_training, drop_remainder, hvd=None):
    name_to_features = {
        "input_ids": tf.io.FixedLenFeature([seq_length], tf.int64),
        "input_mask": tf.io.FixedLenFeature([seq_length], tf.int64),
        "segment_ids": tf.io.FixedLenFeature([seq_length], tf.int64),
        "label_ids": tf.io.FixedLenFeature([], tf.int64),
        "is_real_example": tf.io.FixedLenFeature([], tf.int64) 
    }

    def _decode_record(record, name_to_features):
        example = tf.parse_single_example(record, name_to_features)
        for name in list(example.keys()):
            t = example[name]
            if t.dtype == tf.int64:
                t = tf.to_int32(t)
            example[name] = t
        return example

    def input_fn(params):
        d = tf.data.TFRecordDataset(input_file)
        if is_training:
            if hvd is not None: d = d.shard(hvd.size(), hvd.rank())
            d = d.repeat()
            d = d.shuffle(buffer_size=100)

        d = d.apply(tf.contrib.data.map_and_batch(
            lambda record: _decode_record(record, name_to_features),
            batch_size=batch_size,
            drop_remainder=drop_remainder
        ))
        return d

    return input_fn


def create_model(bert_config, is_training, input_ids, input_mask,
                 segment_ids, labels, num_labels, use_one_hot_embeddings, keep_prob):
    model = modeling.BertModel(
        config=bert_config,
        is_training=is_training,
        input_ids=input_ids,
        input_mask=input_mask,
        token_type_ids=segment_ids,
        use_one_hot_embeddings=use_one_hot_embeddings
    )

    output_layer = model.get_pooled_output()

    hidden_size = output_layer.shape[-1].value

    output_weight = tf.get_variable(
        "output_weights", [num_labels, hidden_size],
        initializer=tf.truncated_normal_initializer(stddev=0.02)
    )
    output_bias = tf.get_variable(
        "output_bias", [num_labels], initializer=tf.zeros_initializer()
    )
    with tf.variable_scope("loss"):
        if is_training:
            output_layer = tf.nn.dropout(output_layer, keep_prob=keep_prob)
        logits = tf.matmul(output_layer, output_weight, transpose_b=True)
        logits = tf.nn.bias_add(logits, output_bias)
        probabilities=tf.nn.softmax(logits, axis=-1)
        ##########################################################################
        log_probs = tf.nn.log_softmax(logits, axis=-1)
        one_hot_labels = tf.one_hot(labels, depth=num_labels, dtype=tf.float32)
        per_example_loss = -tf.reduce_sum(one_hot_labels * log_probs, axis=-1)
        loss = tf.reduce_mean(per_example_loss)
        return (loss, per_example_loss, logits, probabilities)
        ##########################################################################


def model_fn_builder(bert_config, num_labels, init_checkpoint=None, learning_rate=None,
                     num_train_steps=None, num_warmup_steps=None,
                     use_one_hot_embeddings=False, hvd=None, use_fp16=False, keep_prob=0.9):
    def model_fn(features, labels, mode, params):
        tf.compat.v1.logging.info("*** Features ***")
        for name in sorted(features.keys()):
            tf.compat.v1.logging.info("  name = %s, shape = %s" % (name, features[name].shape))
        input_ids = features["input_ids"]
        input_mask = features["input_mask"]
        segment_ids = features["segment_ids"]
        label_ids = features["label_ids"]
        is_real_example= None
        if "is_real_example" in features:
            is_real_example = tf.cast(features["is_real_example"], dtype=tf.float32)
        else:
            is_real_example = tf.ones(tf.shape(label_ids), dtype=tf.float32)

        is_training = (mode == tf.estimator.ModeKeys.TRAIN)

        (total_loss, per_example_loss, logits, probabilities) = create_model(
            bert_config, is_training, input_ids, input_mask, segment_ids, label_ids,
            num_labels, use_one_hot_embeddings, keep_prob)
        tvars = tf.trainable_variables()
        initialized_variable_names = {}
        scaffold_fn = None
        if init_checkpoint and (hvd is None or hvd.rank() == 0):
            (assignment_map,
             initialized_variable_names) = modeling.get_assignment_map_from_checkpoint(tvars,
                                                                                       init_checkpoint)
            tf.train.init_from_checkpoint(init_checkpoint, assignment_map)
        tf.compat.v1.logging.info("**** Trainable Variables ****")

        for var in tvars:
            init_string = ""
            if var.name in initialized_variable_names:
                init_string = ", *INIT_FROM_CKPT*"
            tf.compat.v1.logging.info("  name = %s, shape = %s%s", var.name, var.shape,
                            init_string)
        output_spec = None
        if mode == tf.estimator.ModeKeys.TRAIN:
            train_op = optimization.create_optimizer(
                total_loss, learning_rate, num_train_steps, num_warmup_steps, hvd, False, use_fp16)
            def metric_fn(per_example_loss, label_ids, logits, is_real_example):
                predictions = tf.argmax(logits, axis=-1, output_type=tf.int64)
                accuracy = tf.compat.v1.metrics.accuracy(
                    labels=label_ids, predictions=predictions, weights=is_real_example)
                return {
                    "eval_accuracy": accuracy
               }
            eval_metric_ops = metric_fn(per_example_loss, label_ids, logits, is_real_example)        
            output_spec = tf.estimator.EstimatorSpec(
              mode=mode,
              loss=total_loss,
              train_op=train_op,
              eval_metric_ops=eval_metric_ops
              )
        elif mode == tf.estimator.ModeKeys.EVAL:
            def metric_fn(per_example_loss, label_ids, logits, is_real_example):
                predictions = tf.argmax(logits, axis=-1, output_type=tf.int64)
                accuracy = tf.compat.v1.metrics.accuracy(
                    labels=label_ids, predictions=predictions, weights=is_real_example)
                loss = tf.compat.v1.metrics.mean(values=per_example_loss, weights=is_real_example)
                #recall = tf.compat.v1.metrics.recall(label_ids,predictions,num_labels)
                recall, op_rec = tf.compat.v1.metrics.recall(labels=label_ids, predictions=predictions, weights=is_real_example)
                #precision = tf.compat.v1.metrics.precision(label_ids,predictions,num_labels)
                precision, op_prec = tf.compat.v1.metrics.precision(labels=label_ids, predictions=predictions, weights=is_real_example)
                #f = tf_metrics.f1(label_ids,predictions,num_labels)
                FN = tf.metrics.false_negatives(labels=label_ids, predictions=predictions)
                FP = tf.metrics.false_positives(labels=label_ids, predictions=predictions)
                TP = tf.metrics.true_positives(labels=label_ids, predictions=predictions)
                TN = tf.metrics.true_negatives(labels=label_ids, predictions=predictions)

                #MCC = (TP * TN - FP * FN) / ((TP + FP) * (TP + FN) * (TN + FP) * (TN + FN)) ** 0.5
                #MCC_op = tf.group(FN_op, TN_op, TP_op, FP_op, tf.identity(MCC, name="MCC"))
                f1 = 2 * (precision * recall) / (precision + recall)
                f1_op = tf.group(op_rec, op_prec, tf.identity(f1, name="f1"))
                
                return {
                    "eval_accuracy": accuracy,
                    "eval_loss": loss,
                    "recall": (recall,op_rec),
                    "precision": (precision,op_prec),
                    "f-score": (f1,f1_op),
                    "tp": TP,
                    "tn": TN,
                    "fp": FP,
                    "fn": FN,
                    #"MCC": (MCC, MCC_op)
                }    
                #return {
                #    "eval_accuracy": accuracy,
                #    "eval_loss": loss,
                #}

            eval_metric_ops = metric_fn(per_example_loss, label_ids, logits, is_real_example)
            output_spec = tf.estimator.EstimatorSpec(
              mode=mode,
              loss=total_loss,
              eval_metric_ops=eval_metric_ops)
        else:
            output_spec = tf.estimator.EstimatorSpec(
              mode=mode, predictions={"probabilities":probabilities, "logits":logits})
        return output_spec

    return model_fn


def main(_):
    tf.compat.v1.logging.set_verbosity(tf.compat.v1.logging.INFO)

    if FLAGS.horovod:
      hvd.init()
    if FLAGS.use_fp16:
        os.environ["TF_ENABLE_AUTO_MIXED_PRECISION_GRAPH_REWRITE"] = "1"

    processors = {'consensus':ConsensusProcessor}
    
    tokenization.validate_case_matches_checkpoint(FLAGS.do_lower_case, FLAGS.init_checkpoint)

    if not FLAGS.do_train and not FLAGS.do_eval and not FLAGS.do_predict:
       raise ValueError("At least one of `do_train` or `do_eval` must be True.")

    bert_config = modeling.BertConfig.from_json_file(FLAGS.bert_config_file)

    if FLAGS.max_seq_length > bert_config.max_position_embeddings:
        raise ValueError(
            "Cannot use sequence length %d because the BERT model "
            "was only trained up to sequence length %d" %
            (FLAGS.max_seq_length, bert_config.max_position_embeddings))

    task_name = FLAGS.task_name.lower()
    if task_name not in processors:
        raise ValueError("Task not found: %s" % (task_name))

    input_file_type = FLAGS.input_file_type.lower()

    tf.io.gfile.makedirs(FLAGS.output_dir)

    processor = processors[task_name]()

    #label_list = processor.get_labels()
    label_list,label_map = processor.get_labels()
    inv_label_map = { v: k for k, v in label_map.items() }

    tokenizer = tokenization.FullTokenizer(
        vocab_file=FLAGS.vocab_file, do_lower_case=FLAGS.do_lower_case)

    is_per_host = tf.contrib.tpu.InputPipelineConfig.PER_HOST_V2

    master_process = True
    training_hooks = []
    global_batch_size = FLAGS.train_batch_size
    hvd_rank = 0

    config = tf.compat.v1.ConfigProto()
    if FLAGS.horovod:
      global_batch_size = FLAGS.train_batch_size * hvd.size()
      master_process = (hvd.rank() == 0)
      hvd_rank = hvd.rank()
      config.gpu_options.visible_device_list = str(hvd.local_rank())
      if hvd.size() > 1:
        training_hooks.append(hvd.BroadcastGlobalVariablesHook(0))

    if FLAGS.use_xla:
        config.graph_options.optimizer_options.global_jit_level = tf.compat.v1.OptimizerOptions.ON_1
    run_config = tf.estimator.RunConfig(
      model_dir=FLAGS.output_dir if master_process else None,
      session_config=config,
      save_checkpoints_steps=FLAGS.save_checkpoints_steps if master_process else None,
      keep_checkpoint_max=1)

    if master_process:
      tf.compat.v1.logging.info("***** Configuration *****")
      for key in FLAGS.__flags.keys():
          tf.compat.v1.logging.info('  {}: {}'.format(key, getattr(FLAGS, key)))
      tf.compat.v1.logging.info("**************************")

    train_examples = None
    num_train_steps = None
    num_warmup_steps = None
    training_hooks.append(LogTrainRunHook(global_batch_size, hvd_rank))
    
    if FLAGS.do_train:
        train_examples = processor.get_train_examples(FLAGS.data_dir, FLAGS.input_file_type)
        num_train_steps = int(
            len(train_examples) / global_batch_size * FLAGS.num_train_epochs)
        num_warmup_steps = int(num_train_steps * FLAGS.warmup_proportion)

        start_index = 0
        end_index = len(train_examples)
        tmp_filenames = [os.path.join(FLAGS.output_dir, "train.tf_record")]

        if FLAGS.horovod:
          tmp_filenames = [os.path.join(FLAGS.output_dir, "train.tf_record{}".format(i)) for i in range(hvd.size())]
          num_examples_per_rank = len(train_examples) // hvd.size()
          remainder = len(train_examples) % hvd.size()
          if hvd.rank() < remainder:
            start_index = hvd.rank() * (num_examples_per_rank+1)
            end_index = start_index + num_examples_per_rank + 1
          else:
            start_index = hvd.rank() * num_examples_per_rank + remainder
            end_index = start_index + (num_examples_per_rank)

    model_fn = model_fn_builder(
        bert_config=bert_config,
        num_labels=len(label_list) + 1,
        init_checkpoint=FLAGS.init_checkpoint,
        learning_rate=FLAGS.learning_rate,
        num_train_steps=num_train_steps,
        num_warmup_steps=num_warmup_steps,
        use_one_hot_embeddings=False,
        hvd=None if not FLAGS.horovod else hvd,
        use_fp16=FLAGS.use_fp16,
        keep_prob=FLAGS.keep_prob)

    estimator = tf.estimator.Estimator(
      model_fn=model_fn,
      config=run_config)

    if FLAGS.do_train: 
        filed_based_convert_examples_to_features(
          train_examples[start_index:end_index], label_list, label_map, FLAGS.max_seq_length, tokenizer, tmp_filenames[hvd_rank], FLAGS.replace_span_A, FLAGS.replace_span_B, FLAGS.strategy)
        tf.compat.v1.logging.info("***** Running training *****")
        tf.compat.v1.logging.info("  Num examples = %d", len(train_examples))
        tf.compat.v1.logging.info("  Batch size = %d", FLAGS.train_batch_size)
        tf.compat.v1.logging.info("  Num steps = %d", num_train_steps)
        tf.compat.v1.logging.info("  Num of labels = %d", len(label_list))
        train_input_fn = file_based_input_fn_builder(
            input_file=tmp_filenames,
            batch_size=FLAGS.train_batch_size,
            seq_length=FLAGS.max_seq_length,
            is_training=True,
            drop_remainder=True,
            hvd=None if not FLAGS.horovod else hvd)
        
        train_start_time = time.time()
        estimator.train(input_fn=train_input_fn, max_steps=num_train_steps, hooks=training_hooks)
        train_time_elapsed = time.time() - train_start_time
        train_time_wo_overhead = training_hooks[-1].total_time
        avg_sentences_per_second = num_train_steps * global_batch_size * 1.0 / train_time_elapsed
        ss_sentences_per_second = (num_train_steps - training_hooks[-1].skipped) * global_batch_size * 1.0 / train_time_wo_overhead

        if master_process:
          tf.compat.v1.logging.info("-----------------------------")
          tf.compat.v1.logging.info("Total Training Time = %0.2f for Sentences = %d", train_time_elapsed,
                        num_train_steps * global_batch_size)
          tf.compat.v1.logging.info("Total Training Time W/O Overhead = %0.2f for Sentences = %d", train_time_wo_overhead,
                        (num_train_steps - training_hooks[-1].skipped) * global_batch_size)
          tf.compat.v1.logging.info("Throughput Average (sentences/sec) with overhead = %0.2f", avg_sentences_per_second)
          tf.compat.v1.logging.info("Throughput Average (sentences/sec) = %0.2f", ss_sentences_per_second)
          tf.compat.v1.logging.info("-----------------------------")

    if FLAGS.do_eval and master_process:
        eval_examples = processor.get_dev_examples(FLAGS.data_dir, FLAGS.input_file_type)
        num_actual_eval_examples = len(eval_examples)
        eval_file = os.path.join(FLAGS.output_dir, "eval.tf_record")
        filed_based_convert_examples_to_features(
            eval_examples, label_list, label_map, FLAGS.max_seq_length, tokenizer, eval_file, FLAGS.replace_span_A, FLAGS.replace_span_B, FLAGS.strategy)

        tf.compat.v1.logging.info("***** Running evaluation *****")
        tf.compat.v1.logging.info("  Num examples = %d (%d actual, %d padding)",
                        len(eval_examples), num_actual_eval_examples,
                        len(eval_examples) - num_actual_eval_examples)
        tf.compat.v1.logging.info("  Batch size = %d", FLAGS.eval_batch_size)
        # This tells the estimator to run through the entire set.
        eval_steps = None
        eval_drop_remainder = False
        eval_input_fn = file_based_input_fn_builder(
            input_file=eval_file,
            batch_size=FLAGS.eval_batch_size,
            seq_length=FLAGS.max_seq_length,
            is_training=False,
            drop_remainder=eval_drop_remainder)
        result = estimator.evaluate(input_fn=eval_input_fn, steps=eval_steps)
        output_eval_file = os.path.join(FLAGS.output_dir, "eval_results.txt")
        with tf.io.gfile.GFile(output_eval_file, "w") as writer:
            tf.compat.v1.logging.info("***** Eval results *****")
            for key in sorted(result.keys()):
                tf.compat.v1.logging.info("  %s = %s", key, str(result[key]))
                writer.write("%s = %s\n" % (key, str(result[key])))
    if FLAGS.do_predict and master_process:
        predict_examples = processor.get_test_examples(FLAGS.data_dir, FLAGS.input_file_type)
        num_actual_predict_examples = len(predict_examples)
        predict_file = os.path.join(FLAGS.output_dir, "predict.tf_record")
        filed_based_convert_examples_to_features(predict_examples, label_list, label_map,
                                                 FLAGS.max_seq_length, tokenizer,
                                                 predict_file, FLAGS.replace_span_A, FLAGS.replace_span_B, FLAGS.strategy)
        tf.compat.v1.logging.info("***** Running prediction*****")
        tf.compat.v1.logging.info("  Num examples = %d (%d actual, %d padding)",
                        len(predict_examples), num_actual_predict_examples,
                        len(predict_examples) - num_actual_predict_examples)        
        tf.compat.v1.logging.info("  Batch size = %d", FLAGS.predict_batch_size)

        predict_drop_remainder = False
        predict_input_fn = file_based_input_fn_builder(
            input_file=predict_file,
            batch_size=FLAGS.predict_batch_size,
            seq_length=FLAGS.max_seq_length,
            is_training=False,
            drop_remainder=predict_drop_remainder)

        eval_hooks = [LogEvalRunHook(FLAGS.predict_batch_size)]
        eval_start_time = time.time()

        output_class_file = os.path.join(FLAGS.output_dir, "test_output_labels.txt")
        output_predict_file = os.path.join(FLAGS.output_dir, "test_results.tsv")
        with tf.io.gfile.GFile(output_predict_file, "w") as writer, tf.io.gfile.GFile(output_class_file, "w") as writer2:
            num_written_lines = 0
            tf.compat.v1.logging.info("***** Predict results *****")
            for prediction in estimator.predict(input_fn=predict_input_fn, hooks=eval_hooks,
                                                     yield_single_examples=True):
                probabilities = prediction["probabilities"]
                logits = prediction["logits"]
                pr_res = np.argmax(logits, axis=-1)
                output = str(inv_label_map[pr_res])+"\n"
                writer2.write(output)
                if (FLAGS.input_file_type == "tsv"):
                    output_line = "\t".join(
                        str(class_probability)
                        for class_probability in probabilities) + "\n"
                    writer.write(output_line)
                    num_written_lines += 1
                if (FLAGS.input_file_type == "csv"):
                    output_line = ",".join(
                        str(class_probability)
                        for class_probability in probabilities) + "\n"
                    writer.write(output_line)
                    num_written_lines += 1
        assert num_written_lines == num_actual_predict_examples

        eval_time_elapsed = time.time() - eval_start_time
        eval_time_wo_overhead = eval_hooks[-1].total_time

        time_list = eval_hooks[-1].time_list
        time_list.sort()
        num_sentences = (eval_hooks[-1].count - eval_hooks[-1].skipped) * FLAGS.predict_batch_size

        avg = np.mean(time_list)
        cf_50 = max(time_list[:int(len(time_list) * 0.50)])
        cf_90 = max(time_list[:int(len(time_list) * 0.90)])
        cf_95 = max(time_list[:int(len(time_list) * 0.95)])
        cf_99 = max(time_list[:int(len(time_list) * 0.99)])
        cf_100 = max(time_list[:int(len(time_list) * 1)])
        ss_sentences_per_second = num_sentences * 1.0 / eval_time_wo_overhead

        tf.compat.v1.logging.info("-----------------------------")
        tf.compat.v1.logging.info("Total Inference Time = %0.2f for Sentences = %d", eval_time_elapsed,
                        eval_hooks[-1].count * FLAGS.predict_batch_size)
        tf.compat.v1.logging.info("Total Inference Time W/O Overhead = %0.2f for Sentences = %d", eval_time_wo_overhead,
                        (eval_hooks[-1].count - eval_hooks[-1].skipped) * FLAGS.predict_batch_size)
        tf.compat.v1.logging.info("Summary Inference Statistics")
        tf.compat.v1.logging.info("Batch size = %d", FLAGS.predict_batch_size)
        tf.compat.v1.logging.info("Sequence Length = %d", FLAGS.max_seq_length)
        tf.compat.v1.logging.info("Precision = %s", "fp16" if FLAGS.use_fp16 else "fp32")
        tf.compat.v1.logging.info("Latency Confidence Level 50 (ms) = %0.2f", cf_50 * 1000)
        tf.compat.v1.logging.info("Latency Confidence Level 90 (ms) = %0.2f", cf_90 * 1000)
        tf.compat.v1.logging.info("Latency Confidence Level 95 (ms) = %0.2f", cf_95 * 1000)
        tf.compat.v1.logging.info("Latency Confidence Level 99 (ms) = %0.2f", cf_99 * 1000)
        tf.compat.v1.logging.info("Latency Confidence Level 100 (ms) = %0.2f", cf_100 * 1000)
        tf.compat.v1.logging.info("Latency Average (ms) = %0.2f", avg * 1000)
        tf.compat.v1.logging.info("Throughput Average (sentences/sec) = %0.2f", ss_sentences_per_second)
        tf.compat.v1.logging.info("-----------------------------")

if __name__ == "__main__":
    flags.mark_flag_as_required("data_dir")
    flags.mark_flag_as_required("task_name")
    flags.mark_flag_as_required("input_file_type")
    flags.mark_flag_as_required("vocab_file")
    flags.mark_flag_as_required("bert_config_file")
    flags.mark_flag_as_required("output_dir")
    tf.compat.v1.app.run()

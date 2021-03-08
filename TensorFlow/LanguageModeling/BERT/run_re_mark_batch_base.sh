#!/bin/bash

MAX_JOBS=300
#output-biobert is a symlink to the project output folder
#mkdir -p output-biobert/relationextraction/large
mkdir -p output-biobert/relationextraction/base

###model="/scratch/project_2001426/models/biobert_large"
model="/scratch/project_2001426/models/biobert_v1.1_pubmed"
data_dir="data/farrokh_comparison/json_examples_all_entities_tsv/unmasked_entities/not_crossing_sentence_boundary"

LEARNING_RATE="2e-5 3e-5 5e-5 5e-6"

EPOCHS="4 5 8"

type_="consensus"

strategy="mark"

KEEP_PROB="0.9 1"

file_type="csv"

MAX_SEQ_LEN="96 256"
init_ckpt="/scratch/project_2001426/models/biobert_v1.1_pubmed/model.ckpt-1000000"

for learning_rate in $LEARNING_RATE; do
    for epochs in $EPOCHS; do
        for keep_prob in $KEEP_PROB; do
            for max_seq_len in $MAX_SEQ_LEN; do
                jobs=$(ls output-biobert/relationextraction/large | wc -l)
                echo "Submitting job with params $model $max_seq_len $learning_rate $epochs $keep_prob "
                job_id=$(
                sbatch slurm-run-re-mark.sh \
                    $model \
                    $data_dir \
                    $max_seq_len \
                    $learning_rate \
                    $epochs \
                    $type_ \
                    $init_ckpt \
                    $file_type \
                    $strategy \
                    $keep_prob \
                    | perl -pe 's/Submitted batch job //'
                    )
                echo "Submitted batch job $job_id"
                #change to base for base model
                touch output-biobert/relationextraction/base/$job_id
                sleep 2
            done
        done
    done
done

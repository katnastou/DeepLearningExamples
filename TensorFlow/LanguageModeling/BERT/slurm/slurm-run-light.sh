#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64G
#SBATCH -p gpu
#SBATCH -t 72:00:00
#SBATCH --gres=gpu:v100:1
#SBATCH --ntasks-per-node=1
<<<<<<< HEAD
#SBATCH --account=Project_2001426
=======
#SBATCH --account=Project_<number>
>>>>>>> c28b7e16874bafb19144c4d22b217fa428281796
#SBATCH -o logs/%j.out
#SBATCH -e logs/%j.err

module purge
#if not you get CUDA OOM errors
module load gcc/8.3.0 cuda/10.1.168
#for multiple gpus
module load hpcx-mpi/2.4.0
module load tensorflow/1.15-hvd

OUTPUT_DIR="output-biobert/singlegpu/$SLURM_JOBID"
mkdir -p $OUTPUT_DIR

#check for all parameters
if [ "$#" -ne 8 ]; then
    echo "Usage: $0 model_dir data_dir max_seq_len batch_size learning_rate epochs task init_checkpoint"
    exit 1
fi

BERT_DIR=${1:-"models/biobert_large"}
DATASET_DIR=${2:-"scratchdata/4-class-10K-w20"}
MAX_SEQ_LENGTH="$3"
BATCH_SIZE="$4"
LEARNING_RATE="$5"
EPOCHS="$6"
TASK=${7:-"consensus"}
INIT_CKPT=${8:-"models/biobert_large/bert_model.ckpt"}

cased="true"

if [ "$cased" = "true" ] ; then
    DO_LOWER_CASE=0
    CASING_DIR_PREFIX="cased"
    case_flag="--do_lower_case=False"
else
    DO_LOWER_CASE=1
    CASING_DIR_PREFIX="uncased"
    case_flag="--do_lower_case=True"
fi

export NCCL_DEBUG=INFO

srun python run_ner_consensus.py \
    --do_prepare=true \
    --do_train=true \
    --do_eval=true \
    --do_predict=true \
    --replace_span="[unused1]" \
    --task_name=$TASK \
    --init_checkpoint=$INIT_CKPT \
    --vocab_file=$BERT_DIR/vocab.txt \
    --bert_config_file=$BERT_DIR/bert_config.json \
    --data_dir=$DATASET_DIR \
    --output_dir=$OUTPUT_DIR \
    --eval_batch_size=$BATCH_SIZE \
    --predict_batch_size=$BATCH_SIZE \
    --max_seq_length=$MAX_SEQ_LENGTH \
    --learning_rate=$LEARNING_RATE \
    --num_train_epochs=$EPOCHS \
    --use_xla \
    --use_fp16 \
    --cased=$cased

result=$(egrep '^INFO:tensorflow:  eval_accuracy' logs/${SLURM_JOB_ID}.err | perl -pe 's/.*accuracy \= (\d)\.(\d{2})(\d{2})\d+$/$2\.$3/')
echo -n 'TEST-RESULT'$'\t'
echo -n 'init_checkpoint'$'\t'"$INIT_CKPT"$'\t'
echo -n 'data_dir'$'\t'"$DATASET_DIR"$'\t'
echo -n 'max_seq_length'$'\t'"$MAX_SEQ_LENGTH"$'\t'
echo -n 'train_batch_size'$'\t'"$BATCH_SIZE"$'\t'
echo -n 'learning_rate'$'\t'"$LEARNING_RATE"$'\t'
echo -n 'num_train_epochs'$'\t'"$EPOCHS"$'\t'
echo -n 'accuracy'$'\t'"$result"$'\n'

seff $SLURM_JOBID


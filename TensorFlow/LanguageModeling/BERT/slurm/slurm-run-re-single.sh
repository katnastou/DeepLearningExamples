#!/bin/bash
# Definining resource we want to allocate. We set 8 tasks, 4 tasks over 2 nodes as we have 4 GPUs per node.
#SBATCH --nodes=1
#SBATCH --ntasks=1

# 6 CPU cores per task to keep the parallel data feeding going. 
#SBATCH --cpus-per-task=6

# Allocate enough memory.
#SBATCH --mem=64G
<<<<<<< HEAD
#SBATCH -p gputest

# Time limit on Puhti's gpu partition is 3 days.
#SBATCH -t 00:15:00
=======
#SBATCH -p gpu

# Time limit on Puhti's gpu partition is 3 days.
#SBATCH -t 04:00:00
>>>>>>> c28b7e16874bafb19144c4d22b217fa428281796

# Allocate 4 GPUs on each node.
#SBATCH --gres=gpu:v100:1
#SBATCH --ntasks-per-node=1

# Puhti project number
<<<<<<< HEAD
#SBATCH --account=Project_2001426
=======
#SBATCH --account=Project_<num>
>>>>>>> c28b7e16874bafb19144c4d22b217fa428281796

# Log file locations, %j corresponds to slurm job id. symlinks didn't work. Will add hard links to directory instead. Now it saves in projappl dir.
#SBATCH -o logs/%j.out
#SBATCH -e logs/%j.err

# Clear all modules
module purge
#if not you may get CUDA OOM errors
#module load gcc/8.3.0 cuda/10.1.168
#for multiple gpus
#module load hpcx-mpi/2.4.0
#load tensorflow with horovod support
module load tensorflow/1.15-hvd

OUTPUT_DIR="output-biobert/multigpu/$SLURM_JOBID"
mkdir -p $OUTPUT_DIR

#uncomment to delete output!!!
function on_exit {
    rm -rf "$OUTPUT_DIR"
    rm -f jobs/$SLURM_JOBID
}
trap on_exit EXIT

#check for all parameters
if [ "$#" -ne 8 ]; then
    echo "Usage: $0 model_dir data_dir max_seq_len batch_size learning_rate epochs task init_checkpoint"
    exit 1
fi
#command example from BERT folder in projappl dir:
#sbatch slurm/slurm-run-re.sh models/biobert_large data/brat_annotation_april_2020 96 32 5e-6 10 consensus models/biobert_large/bert_model.ckpt

#models --> symlink to models dir in scratch
#scratchdata --> symlink to data dir in scratch

BERT_DIR=${1:-"models/biobert_large"}
DATASET_DIR=${2:-"scratchdata/4-class-10K-w20"}
MAX_SEQ_LENGTH="$3"
BATCH_SIZE="$4"
LEARNING_RATE="$5"
EPOCHS="$6"
TASK=${7:-"consensus"}
INIT_CKPT=${8:-"models/biobert_large/bert_model.ckpt"}

# #fix in case you want to use uncased models
# #start with this 
# if [[ $BERT_DIR =~ "uncased" ]]; then
#     cased="--do_lower_case"
# else
#     cased=""
# fi

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

#rm -rf "OUTPUT_DIR"
#mkdir -p "$OUTPUT_DIR"

#export NCCL_IB_HCA="^mlx5_1:1"

export NCCL_DEBUG=INFO

#export OMP_PROC_BIND=true
echo "START $SLURM_JOBID: $(date)"

#srun python run_re_consensus.py \
srun python run_re_masked_consensus.py \
    --do_prepare=true \
    --do_train=true \
    --do_eval=true \
    --do_predict=false \
    --replace_span_A="[unused1]" \
    --replace_span_B="[unused2]" \
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
    --use_fp16 \
    --use_xla \
    --horovod \
    --cased=$cased


result=$(egrep '^INFO:tensorflow:  eval_accuracy' logs/${SLURM_JOB_ID}.err | perl -pe 's/.*accuracy \= (\d)\.(\d{2})(\d{2})\d+$/$2\.$3/')
precision=$(egrep '^INFO:tensorflow:  precision' logs/${SLURM_JOB_ID}.err | perl -pe 's/.*precision \= (\d)\.(\d{2})(\d{2})\d+$/$2\.$3/')
recall=$(egrep '^INFO:tensorflow:  recall' logs/${SLURM_JOB_ID}.err | perl -pe 's/.*recall \= (\d)\.(\d{2})(\d{2})\d+$/$2\.$3/')
f1=$(egrep '^INFO:tensorflow:  f-score' logs/${SLURM_JOB_ID}.err | perl -pe 's/.*score \= (\d)\.(\d{2})(\d{2})\d+$/$2\.$3/')

echo -n 'TEST-RESULT'$'\t'
echo -n 'init_checkpoint'$'\t'"$INIT_CKPT"$'\t'
echo -n 'data_dir'$'\t'"$DATASET_DIR"$'\t'
echo -n 'max_seq_length'$'\t'"$MAX_SEQ_LENGTH"$'\t'
echo -n 'train_batch_size'$'\t'"$BATCH_SIZE"$'\t'
echo -n 'learning_rate'$'\t'"$LEARNING_RATE"$'\t'
echo -n 'num_train_epochs'$'\t'"$EPOCHS"$'\n'
echo -n 'accuracy'$'\t'"$result"$'\t'
echo -n 'precision'$'\t'"$precision"$'\t'
echo -n 'recall'$'\t'"$recall"$'\t'
echo -n 'f1'$'\t'"$f1"$'\n'


seff $SLURM_JOBID

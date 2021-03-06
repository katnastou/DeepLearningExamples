#!/bin/bash
# Definining resource we want to allocate. We set 8 tasks, 4 tasks over 2 nodes as we have 4 GPUs per node.
#SBATCH --nodes=2
#SBATCH --ntasks=8

# 6 CPU cores per task to keep the parallel data feeding going. 
#SBATCH --cpus-per-task=6

# Allocate enough memory.
#SBATCH --mem=160G
#SBATCH -p gpu

# Time limit on Puhti's gpu partition is 3 days.
#SBATCH -t 72:00:00
###SBATCH -t 00:15:00
#SBATCH -J 5-20M2E

# Allocate 4 GPUs on each node.
#SBATCH --gres=gpu:v100:4
#SBATCH --ntasks-per-node=4

#Exclude nodes
#SBATCH --exclude=r04g05,r14g07,r15g08

# Puhti project number
#SBATCH --account=Project_2001426

# Log file locations, %j corresponds to slurm job id. symlinks didn't work. Will add hard links to directory instead. Now it saves in projappl dir.
#SBATCH -o logs/%j.out
#SBATCH -e logs/%j.err

# Clear all modules
module purge
#if not you may get CUDA OOM errors
#module load gcc/8.3.0 
#module load gcc/9.1.0
#module load cuda/10.1.168
#for multiple gpus
#module load hpcx-mpi/2.4.0
#module load intel/19.0.4
#module load mpich/3.3.1
#module load intel/18.0.5
#module load intel-mpi/18.0.5
#load tensorflow with horovod support
module load tensorflow/1.15-hvd
#module load tensorflow/1.13.1-hvd
#module load tensorflow/2.0.0-hvd

#OUTPUT_DIR="output-biobert/multigpu/$SLURM_JOBID"
#mkdir -p $OUTPUT_DIR

#uncomment to delete output!!!
#function on_exit {
#    rm -rf "$OUTPUT_DIR"
#    rm -f jobs/$SLURM_JOBID
#}
#trap on_exit EXIT

#check for all parameters
if [ "$#" -ne 9 ]; then #make 9 if you add label dir
    echo "Usage: $0 model_dir data_dir max_seq_len batch_size learning_rate epochs task checkpoint_dir labels_dir"
    exit 1
fi
#command example from BERT folder in projappl dir:
#sbatch slurm/slurm-run.sh models/biobert_large scratchdata/4-class-10K-w20 64 32 5e-6 4 consensus models/biobert_large/bert_model.ckpt

#models --> symlink to models dir in scratch
#scratchdata --> symlink to data dir in scratch

BERT_DIR=${1:-"models/biobert_large"}
DATASET_DIR=${2:-"scratchdata/4-class-10K-w20"}
MAX_SEQ_LENGTH="$3"
BATCH_SIZE="$4"
LEARNING_RATE="$5"
EPOCHS="$6"
TASK=${7:-"consensus"}
#INIT_CKPT=${8:-"models/biobert_large/bert_model.ckpt"}
OUTPUT_DIR="$8"
LABELS_DIR="$9"
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
#export TF_XLA_FLAGS=--tf_xla_cpu_global_jit
export NCCL_DEBUG=INFO
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
#https://horovod.readthedocs.io/en/latest/troubleshooting_include.html#running-out-of-memory
export NCCL_P2P_DISABLE=1
#export OMP_PROC_BIND=true
echo "START $SLURM_JOBID: $(date)"

#Pass --output_dir="path_to_checkpoint_folder" if you want to resume from the latest checkpoint in the folder and use both weights and global step.
#Pass --init_checkpoint="path_to_checkpoint" if you only want to resume to use weights and not the global step. For example, if you want to finetune using a pretrained checkpoint, you don't want to use the global step count of pretraining.

srun python run_ner_consensus.py \
    --do_prepare=true \
    --do_train=true \
    --do_eval=true \
    --do_predict=true \
    --replace_span="[unused1]" \
    --task_name=$TASK \
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
    --horovod \
    --cased=$cased \
    --use_xla \
    --labels_dir=$LABELS_DIR 

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

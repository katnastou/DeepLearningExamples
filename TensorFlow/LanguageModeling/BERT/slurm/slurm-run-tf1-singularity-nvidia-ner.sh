#!/bin/bash
# Definining resource we want to allocate. We set 8 tasks, 4 tasks over 2 nodes as we have 4 GPUs per node.
#SBATCH --nodes=2
#SBATCH --ntasks=8

# 6 CPU cores per task to keep the parallel data feeding going. 
#SBATCH --cpus-per-task=6

# Allocate enough memory.
#SBATCH --mem=64G
###SBATCH -p gpu
#SBATCH -p gputest
# Time limit on Puhti's gpu partition is 3 days.
###SBATCH -t 72:00:00
#SBATCH -t 00:15:00

# Allocate 4 GPUs on each node.
#SBATCH --gres=gpu:v100:4
#SBATCH --ntasks-per-node=4

# Puhti project number
#SBATCH --account=Project_2001426

# Log file locations, %j corresponds to slurm job id. symlinks didn't work. Will add hard links to directory instead. Now it saves in projappl dir.
#SBATCH -o logs/%j.out
#SBATCH -e logs/%j.err

# Clear all modules
module purge
#module load hpcx-mpi/2.4.0

OUTPUT_DIR="output-biobert/multigpu/$SLURM_JOBID"
mkdir -p $OUTPUT_DIR

#uncomment to delete output!!!
#function on_exit {
#    rm -rf "$OUTPUT_DIR"
#    rm -f jobs/$SLURM_JOBID
#}
#trap on_exit EXIT

#check for all parameters
if [ "$#" -ne 8 ]; then
    echo "Usage: $0 model_dir data_dir max_seq_len batch_size learning_rate epochs task init_checkpoint"
    exit 1
fi
#command example from BERT folder in projappl dir:
#sbatch slurm/slurm-run.sh models/biobert_large scratchdata/4-class-10K-w20 64 32 5e-6 4 consensus models/biobert_large/bert_model.ckpt

#models --> symlink to models dir in scratch
#scratchdata --> symlink to data dir in scratch
#add an option for all  so that I don't check for all parameters
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

export NCCL_DEBUG=INFO

echo "START $SLURM_JOBID: $(date)"

srun singularity exec --nv --bind /projappl:/projappl --bind /scratch:/scratch \
    /projappl/project_2001426/tensorflow-20.03-tf1-py3.sif \
    python3 run_ner.py \
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
    --use_fp16 \
    --use_xla \
<<<<<<< HEAD
    --cased=$cased ##\
##    --horovod
=======
    --cased=$cased \
    --horovod
>>>>>>> c28b7e16874bafb19144c4d22b217fa428281796



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

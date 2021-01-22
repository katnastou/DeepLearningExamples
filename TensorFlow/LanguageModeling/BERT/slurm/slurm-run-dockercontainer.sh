#!/bin/bash
#SBATCH --nodes=2
#SBATCH --ntasks=8
#SBATCH --cpus-per-task=6
#SBATCH --mem=96G
#SBATCH -p gpu
#SBATCH -t 01:00:00
#SBATCH --gres=gpu:v100:4
#SBATCH --ntasks-per-node=4
#SBATCH --account=Project_2001426
#SBATCH -o /projappl/project_2001426/DeepLearningExamples/TensorFlow/LanguageModeling/BERT/logs/%j.out
#SBATCH -e /projappl/project_2001426/DeepLearningExamples/TensorFlow/LanguageModeling/BERT/logs/%j.err

module purge
#if not you get CUDA OOM errors
module load gcc/8.3.0 cuda/10.1.168
module load hpcx-mpi

OUTPUT_DIR="/projappl/project_2001426/DeepLearningExamples/TensorFlow/LanguageModeling/BERT/results"

cased="true"
batch_size=16

if [ "$cased" = "true" ] ; then
    DO_LOWER_CASE=0
    CASING_DIR_PREFIX="cased"
    case_flag="--do_lower_case=False"
else
    DO_LOWER_CASE=1
    CASING_DIR_PREFIX="uncased"
    case_flag="--do_lower_case=True"
fi

BERT_DIR="/scratch/project_2001426/models/biobert_large"

DATASET_DIR="/projappl/project_2001426/DeepLearningExamples/TensorFlow/LanguageModeling/BERT/data/biobert/BC5CDR/chem"

export NCCL_DEBUG=INFO

srun singularity exec --nv --bind /projappl/project_2001426:/projappl/project_2001426 --bind /scratch/project_2001426/models:/scratch/project_2001426/models \
    /projappl/project_2001426/tensorflow_19.08-py3.sif \
    python run_ner.py \
    --do_prepare=true \
    --do_eval=true \
    --do_predict=true \
    --task_name="bc5cdr" \
    --init_checkpoint="/scratch/project_2001426/models/biobert_large/bert_model.ckpt" \
    --vocab_file=$BERT_DIR/vocab.txt \
    --bert_config_file=$BERT_DIR/bert_config.json \
    --data_dir=$DATASET_DIR \
    --output_dir=$OUTPUT_DIR \
    --eval_batch_size=$batch_size \
    --predict_batch_size=$batch_size \
    --max_seq_length=64 \
    --use_fp16 \
    --use_xla \
    --horovod \
    --cased=$cased

seff $SLURM_JOBID

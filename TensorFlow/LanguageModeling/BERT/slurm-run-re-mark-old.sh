#!/bin/bash
# Definining resource we want to allocate. We set 8 tasks, 4 tasks over 2 nodes as we have 4 GPUs per node.
#SBATCH --nodes=1
#SBATCH --ntasks=1

# 6 CPU cores per task to keep the parallel data feeding going. 
#SBATCH --cpus-per-task=6

# Allocate enough memory.
#SBATCH --mem=100G
#SBATCH -p gpu
###SBATCH -p gputest
# Time limit on Puhti's gpu partition is 3 days.
#SBATCH -t 03:00:00
###SBATCH -t 00:15:00
# Allocate 4 GPUs on each node.
#SBATCH --gres=gpu:v100:1
#SBATCH --ntasks-per-node=1

# Puhti project number
#SBATCH --account=Project_2001426

# Log file locations, %j corresponds to slurm job id. symlinks didn't work. Will add hard links to directory instead. Now it saves in projappl dir.
#SBATCH -o logs/relationextraction/%j.out
#SBATCH -e logs/relationextraction/%j.err

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

#function on_exit {
#    rm -rf "$OUTPUT_DIR"
#    rm -f jobs/$SLURM_JOBID
#}
#trap on_exit EXIT

#check for all parameters
if [ "$#" -ne 10 ]; then
    echo "Usage: $0 model_dir data_dir max_seq_len  learning_rate epochs task init_checkpoint input_file_type strategy keep_prob"
    exit 1
fi
#command example from BERT folder in projappl dir:
#sbatch slurm/slurm-run-re.sh models/biobert_large data/brat_annotation_april_2020 96 32 5e-6 10 consensus models/biobert_large/bert_model.ckpt

#models --> symlink to models dir in scratch
#scratchdata --> symlink to data dir in scratch

BERT_DIR=${1:-"models/biobert_large"}
DATASET_DIR=${2:-"scratchdata/4-class-10K-w20"}
MAX_SEQ_LENGTH="$3"
#BATCH_SIZE="$4"
LEARNING_RATE="$4"
EPOCHS="$5"
TASK=${6:-"consensus"}
INIT_CKPT=${7:-"models/biobert_large/bert_model.ckpt"}
FILE_TYPE="$8"
STRATEGY="$9"
KEEP_PROB="${10}"
# #fix in case you want to use uncased models
# #start with this 
# if [[ $BERT_DIR =~ "uncased" ]]; then
#     cased="--do_lower_case"
# else
#     cased=""
# fi

if [[ $BERT_DIR =~ "large" ]]; then
        BATCH_SIZE=5
else
        BATCH_SIZE=16
fi

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

srun python run_re_masked_consensus.py \
    --do_prepare=true \
    --do_train=true \
    --do_eval=true \
    --do_predict=true \
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
    --input_file_type=$FILE_TYPE \
    --strategy=$STRATEGY \
    --keep_prob=$KEEP_PROB \
    --use_fp16 \
    --use_xla \
    --horovod \
    --cased=$cased


result=$(egrep '^INFO:tensorflow:  eval_accuracy' logs/relationextraction/${SLURM_JOB_ID}.err | perl -pe 's/.*accuracy \= (\d)\.(\d{2})(\d{2})\d+$/$2\.$3/')
echo -n 'TEST-RESULT'$'\t'
echo -n 'init_checkpoint'$'\t'"$INIT_CKPT"$'\t'
echo -n 'data_dir'$'\t'"$DATASET_DIR"$'\t'
echo -n 'max_seq_length'$'\t'"$MAX_SEQ_LENGTH"$'\t'
echo -n 'train_batch_size'$'\t'"$BATCH_SIZE"$'\t'
echo -n 'learning_rate'$'\t'"$LEARNING_RATE"$'\t'
echo -n 'num_train_epochs'$'\t'"$EPOCHS"$'\t'
echo -n 'keep_prob'$'\t'"$KEEP_PROB"$'\t'
echo -n 'strategy'$'\t'"$STRATEGY"$'\t'
echo -n 'accuracy'$'\t'"$result"$'\n'

if ["$FILE_TYPE" = "tsv"]; then
	paste <(paste ${DATASET_DIR}"/test.tsv" ${OUTPUT_DIR}"/test_output_labels.txt") ${OUTPUT_DIR}"/test_results.tsv" | awk -F'\t' '{printf("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t\'\{\''Not_a_complex'\'': %s'\,' '\''Complex_formation'\'': %s'\}'\n",$1,$2,$3,$4,$5,$6,$7,$8,$9,$10)}' > ${OUTPUT_DIR}"/output_with_probabilities_dict.tsv"; 
else
	paste -d, <(paste -d, <(gawk -v RS='"' 'NR % 2 == 0{ gsub(/\n/, "") } { printf("%s%s", $0, RT) }' ${DATASET_DIR}"/test.tsv"  | awk -F, '{printf("%s,%s,%s\n", $1, $3, $4)}') ${OUTPUT_DIR}"/test_output_labels.txt") ${OUTPUT_DIR}"/test_results.tsv" | awk -F',' '{printf("%s\t%s\t%s\t%s\t\'\{\''Not_a_complex'\'': %s'\,' '\''Complex_formation'\'': %s'\}'\n",$1,$2,$3,$4,$5,$6)}' > ${OUTPUT_DIR}"/output_with_probabilities_dict.tsv";
fi

cp -r "data/farrokh_comparison/brat/devel/complex-formation-batch-02-only-entities/" ${OUTPUT_DIR}

counter=0; while IFS=$'\t' read -r f1 f2 f3 f4 f5; do if [ "$pmid" != "$f1" ]; then counter=0; pmid=$f1; if [ "$f4" == "Complex_formation" ]; then counter=1; echo -e "R$counter\t$f4 Arg1:$f2 Arg2:$f3" >> ${OUTPUT_DIR}"/complex-formation-batch-02-only-entities/"$pmid".ann"; fi; else if [ "$f4" == "Complex_formation" ];then counter=$((counter+1)); echo -e "R$counter\t$f4 Arg1:$f2 Arg2:$f3" >> ${OUTPUT_DIR}"/complex-formation-batch-02-only-entities/"$pmid".ann"; fi; fi; done <${OUTPUT_DIR}/output_with_probabilities_dict.tsv

result2=$(python3 evalsorel.py --entities Protein,Chemical,Complex,Family --relations Complex_formation data/farrokh_comparison/brat/devel/complex-formation-batch-02/ ${OUTPUT_DIR}/complex-formation-batch-02-only-entities/ | egrep '^TOTAL' | perl -pe 's/TOTAL(.*)$/$1/')
echo -n 'Eval results'$'\t'"$result2"$'\n'

#remove everything up to last - 
#cp ${OUTPUT_DIR}"/output_with_probabilities_dict.tsv" "/scratch/project_2001426/stringdata/week_50/tokenization/output_with_probabilities_tokenization_orgs_all.tsv"

#echo -n 'result written in /scratch/project_2001426/stringdata/week_31_2/species/org-predictions'$'\n'

seff $SLURM_JOBID

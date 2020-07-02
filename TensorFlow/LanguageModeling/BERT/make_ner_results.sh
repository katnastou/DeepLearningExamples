#!/bin/bash
declare -A associative_array
associative_array=(
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-00]=output-biobert/multigpu/2845619
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-01]=output-biobert/multigpu/2845620
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-02]=output-biobert/multigpu/2845621
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-03]=output-biobert/multigpu/2845622
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-04]=output-biobert/multigpu/2845624
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-05]=output-biobert/multigpu/2845625
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-06]=output-biobert/multigpu/2845626
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-07]=output-biobert/multigpu/2845628
)
#remember for double digits remove the prepended 0
file=0
for key in "${!associative_array[@]}"; do 
    paste <(paste $key"/test.tsv" ${associative_array[$key]}"/test_output_labels.txt") ${associative_array[$key]}"/test_results.tsv" | awk -F'\t' '{printf("%s\t%s\t%s\t%s\t%s\t%s\t%s\t\'\{\''che'\'': %s'\,' '\''dis'\'': %s'\,' '\''ggp'\'': %s'\,' '\''org'\'': %s'\,' '\''out'\'': %s'\}'\n",$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)}' > ${associative_array[$key]}"/output_with_probabilities_dict.tsv"; 
    cp ${associative_array[$key]}"/output_with_probabilities_dict.tsv" "/scratch/project_2001426/stringdata/allpredictions02/output_with_probabilities_0"$file".tsv"
    file=$((file+1))
done

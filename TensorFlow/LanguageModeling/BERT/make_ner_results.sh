#!/bin/bash
declare -A associative_array
associative_array=(
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-10]=output-biobert/multigpu/2847245
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-11]=output-biobert/multigpu/2847246
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-12]=output-biobert/multigpu/2847247
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-13]=output-biobert/multigpu/2847248
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-14]=output-biobert/multigpu/2847249
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-15]=output-biobert/multigpu/2850814
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-16]=output-biobert/multigpu/2850818
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-17]=output-biobert/multigpu/2850819
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-18]=output-biobert/multigpu/2850821
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-19]=output-biobert/multigpu/2850822
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-20]=output-biobert/multigpu/2852621
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-21]=output-biobert/multigpu/2852622
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-22]=output-biobert/multigpu/2852623
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-23]=output-biobert/multigpu/2852624
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-24]=output-biobert/multigpu/2852627
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-25]=output-biobert/multigpu/2852628
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-26]=output-biobert/multigpu/2852629
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-27]=output-biobert/multigpu/2852630
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-28]=output-biobert/multigpu/2860265
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-29]=output-biobert/multigpu/2860267
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-30]=output-biobert/multigpu/2860269
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-31]=output-biobert/multigpu/2860271
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-32]=output-biobert/multigpu/2860272
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-33]=output-biobert/multigpu/2860274
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-34]=output-biobert/multigpu/2860276
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-35]=output-biobert/multigpu/2860277
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-36]=output-biobert/multigpu/2860279
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-37]=output-biobert/multigpu/2860280
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-38]=output-biobert/multigpu/2860281
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-39]=output-biobert/multigpu/2860282
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-40]=output-biobert/multigpu/2860285
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-41]=output-biobert/multigpu/2860286
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-42]=output-biobert/multigpu/2860289
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-43]=output-biobert/multigpu/2860292
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-44]=output-biobert/multigpu/2860294
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-45]=output-biobert/multigpu/2860298
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-46]=output-biobert/multigpu/2866359
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-47]=output-biobert/multigpu/2866360
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-48]=output-biobert/multigpu/2866362
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-49]=output-biobert/multigpu/2866363
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-50]=output-biobert/multigpu/2866366
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-51]=output-biobert/multigpu/2866367
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-52]=output-biobert/multigpu/2866368
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-53]=output-biobert/multigpu/2866371
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-54]=output-biobert/multigpu/2866372
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-55]=output-biobert/multigpu/2866373
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-56]=output-biobert/multigpu/2866374
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-57]=output-biobert/multigpu/2866375
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-58]=output-biobert/multigpu/2866376
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-59]=output-biobert/multigpu/2866377
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-60]=output-biobert/multigpu/2866379
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-61]=output-biobert/multigpu/2866382
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-62]=output-biobert/multigpu/2866384
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-63]=output-biobert/multigpu/2866386
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-64]=output-biobert/multigpu/2866941
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-65]=output-biobert/multigpu/2866942
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-66]=output-biobert/multigpu/2866944
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-67]=output-biobert/multigpu/2866945
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-68]=output-biobert/multigpu/2866947
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-69]=output-biobert/multigpu/2866948
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-70]=output-biobert/multigpu/2867594
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-71]=output-biobert/multigpu/2867596
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-72]=output-biobert/multigpu/2867599
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-73]=output-biobert/multigpu/2867603
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-74]=output-biobert/multigpu/2867604
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-75]=output-biobert/multigpu/2867605
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-76]=output-biobert/multigpu/2867609
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-77]=output-biobert/multigpu/2867610
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-78]=output-biobert/multigpu/2867612
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-79]=output-biobert/multigpu/2867615
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-80]=output-biobert/multigpu/2876145
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-81]=output-biobert/multigpu/2869443
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-82]=output-biobert/multigpu/2869444
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-83]=output-biobert/multigpu/2869446
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-84]=output-biobert/multigpu/2876148
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-85]=output-biobert/multigpu/2869448
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-86]=output-biobert/multigpu/2869449
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-87]=output-biobert/multigpu/2869450
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-88]=output-biobert/multigpu/2869451
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-89]=output-biobert/multigpu/2869452
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-90]=output-biobert/multigpu/2869453
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-91]=output-biobert/multigpu/2869454
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-92]=output-biobert/multigpu/2869455
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-93]=output-biobert/multigpu/2870231
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-94]=output-biobert/multigpu/2870233
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-95]=output-biobert/multigpu/2870236
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-96]=output-biobert/multigpu/2871402
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-97]=output-biobert/multigpu/2871405
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-98]=output-biobert/multigpu/2871406
[/scratch/project_2001426/stringdata/currentrun/ggp-contexts-w100-99]=output-biobert/multigpu/2871409
)
#remember for double digits remove the prepended 0
file=10
for key in "${!associative_array[@]}"; do 
    paste <(paste $key"/test.tsv" ${associative_array[$key]}"/test_output_labels.txt") ${associative_array[$key]}"/test_results.tsv" | awk -F'\t' '{printf("%s\t%s\t%s\t%s\t%s\t%s\t%s\t\'\{\''che'\'': %s'\,' '\''dis'\'': %s'\,' '\''ggp'\'': %s'\,' '\''org'\'': %s'\,' '\''out'\'': %s'\}'\n",$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)}' > ${associative_array[$key]}"/output_with_probabilities_dict.tsv"; 
    cp ${associative_array[$key]}"/output_with_probabilities_dict.tsv" "/scratch/project_2001426/stringdata/allpredictions02/output_with_probabilities_"$file".tsv"
    file=$((file+1))
done

#open all ann files and print out the ann with entities only

for f in complex-formation-batch-02/*.ann; do
    grep "^T" $f > complex-formation-batch-02-only-entities/${f##*/};
done


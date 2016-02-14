
if [ ! -f "../ultpit" ] ; then
    echo "ERROR ../ultpit does not exist"
    exit
fi

for d in */ ; do
    if [[ $d != DISABLED* ]] ; then
        if [ -f $d/data.txt.gz ] && [ -f $d/params.json ] && [ -f $d/expected.txt.gz ] ; then
            printf "run $d\r"
            rm -f $d/result.txt.gz

            TIME=$({ time ../ultpit $d/params.json --input $d/data.txt.gz --output $d/result.txt.gz --log $d/log.txt; } |& grep real)
            DIFF=$( diff $d/result.txt.gz $d/expected.txt.gz )
            if [ "$DIFF" != "" ] ; then
                echo "$d: RESULTS DIFFERENT OH NO"
            else
                echo "$d: ${TIME:5}"
            fi
        else
            echo "$d: SKIPPING ensure data.txt.gz params.json expected.txt.gz"
        fi
    fi
done


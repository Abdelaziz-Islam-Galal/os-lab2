#!/bin/bash

flagged_extensions=(.exe .bat .vbs .scr .ps1)
flagged_content=(virus trojan malware worm ransomware)

if [ $# -ne 3 ]
then
echo
echo "insuffecient arguments"
echo 
echo "Usage arguments: <dir> <malicious_dir> <interval-secs>"
echo "dir — the source directory being monitored (files only, no subdirectories)"
echo "malicious_dir — the destination directory where flagged/quarantined files are copied"
echo "interval-secs — time to wait between every check"
echo
exit 1
else
dir="$1"
malicious_dir="$2"
interval_secs="$3"
fi

# create directories if they don't exist
# -p option ensures that no error is thrown if the directory already exists
mkdir -p "$dir"
mkdir -p "$malicious_dir"

ls -l $dir > directory-info.last

while true
do
    sleep "$interval_secs"
    
    ls -l "$dir" > directory-info.new
    
    cmp -s directory-info.last directory-info.new # the -s is to stop oitput appearing in the terminal
    compare=$?
    
    if [[ 2 -eq "$compare" ]]
    then
        echo "error occured in comparing new and old status"
        continue
    elif [[ 1 -eq "$compare" ]]
    then
        for file in $(ls "$dir") # expand ls output into a list of file names then iterate
        do
            is_malicious=false
            for ext in "${flagged_extensions[@]}"
            do
                if [[ "$file" == *"$ext" ]]
                then
                    is_malicious=true
                    break
                fi
            done
            for content in "${flagged_content[@]}"
            do
                if grep -iwq "$content" "$dir/$file" # -i to be case-insensitive, -w to match whole words, -q to prevent output to the terminal
                then
                    is_malicious=true
                    break
                fi
            done
            if [[ $is_malicious == true ]]
            then
                echo "$file is malicious and it is DELETED"
                cp "$dir/$file" "$malicious_dir"
                rm -f "$dir/$file"
            fi
        done
    fi


    cp directory-info.new directory-info.last
done




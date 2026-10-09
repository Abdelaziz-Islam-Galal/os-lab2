#!/bin/bash

flagged_extensions=(.exe .bat .vbs .scr .ps1)
flagged_content=(virus trojan malware worm ransomware)

scan_files() {
    dir="$1"
    malicious_dir="$2"
    
    files=("$dir"/*)

    IFS=$'\n' white_list=($(cat "$white_list_file")) # IFS = Internal Field Separator

    if [[ "${files[0]}" == "$dir/*" ]] # in practive if there are no files it returns the string "$dir/*"
    then
        return 0 # of no files in dir skip scan
    fi

    for file_path in "${files[@]}"
    do
        is_malicious=false
        for ext in "${flagged_extensions[@]}"
        do
            if [[ "$file_path" == *"$ext" ]]
            then
                is_malicious=true
                break
            fi
        done
        for content in "${flagged_content[@]}"
        do
            if grep -iq "$content" "$file_path" # -i to be case-insensitive, -w to match whole words, -q to prevent output to the terminal
            then
                is_malicious=true
                break
            fi
        done
        if [[ $is_malicious == true ]] # needed to put the condidition where removing file occurs at the end to avoid an error 
        then
            for white_file in "${white_list[@]}"; do
                if [[ "$(date -r "${file_path}") ${file_path##*/}" == "$white_file" ]]
                then
                    is_malicious=false
                    break
                fi
            done
            if [[ $is_malicious == true ]]
            then
                echo "${file_path##*/} is malicious and it is DELETED"
                mv "$file_path" "$malicious_dir"
            fi
        fi
    done
    ls -l "$dir" > directory-info.new
}

if [[ $# -ne 3 ]]
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

if [[ $dir == $malicious_dir ]]
then
    echo "Error: dir and malicious_dir cannot be the same."
    exit 1
fi

# create directories if they don't exist
# -p option ensures that no error is thrown if the directory already exists
mkdir -p "$dir"
mkdir -p "$malicious_dir"

white_list_file="$malicious_dir/white.list"
touch "$white_list_file" # create file if it doesn't exist to avoid error with cat

ls -l "$dir" > directory-info.last

scan_files "$dir" "$malicious_dir"

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
        scan_files "$dir" "$malicious_dir"
    fi

    cp directory-info.new directory-info.last
done




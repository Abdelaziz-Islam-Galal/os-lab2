#!/bin/bash

flagged_extensions=(.exe .bat .vbs .scr .ps1)
flagged_content=(virus trojan malware worm ransomware)

scan_files() {
    dir="$1"
    malicious_dir="$2"
    
    files=("$dir"/*)

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
            echo "${file_path##*/} is malicious and it is DELETED"
            cp "$file_path" "$malicious_dir"
            rm -f "$file_path"
        fi
    done
}

if [[ $# -ne 2 ]]
then
echo
echo "insuffecient arguments"
echo 
echo "Usage arguments: <dir> <malicious_dir>"
echo "dir — the source directory being monitored (files only, no subdirectories)"
echo "malicious_dir — the destination directory where flagged/quarantined files are copied"
echo
exit 1
else
dir="$1"
malicious_dir="$2"
path_malicious_dir="${malicious_dir%/*}"
directory_info_last="$path_malicious_dir/directory-info.last"
directory_info_new="$path_malicious_dir/directory-info.new"
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

sleep 23

if [[ ! -e "$directory_info_last" ]]
then
    ls -l "$dir" > "$directory_info_last"
    scan_files "$dir" "$malicious_dir"
else
    ls -l "$dir" > "$directory_info_new"
    
    cmp -s "$directory_info_last" "$directory_info_new" # the -s is to stop oitput appearing in the terminal
    compare=$?
    
    if [[ 2 -eq "$compare" ]]
    then
        echo "error occured in comparing new and old status"
        exit 2
    elif [[ 1 -eq "$compare" ]]
    then
        scan_files "$dir" "$malicious_dir"
    fi

    cp "$directory_info_new" "$directory_info_last"
fi



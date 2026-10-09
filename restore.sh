#!/bin/bash

if [ $# -ne 2 ]
then
echo
echo "insuffecient arguments"
echo 
echo "Usage arguments: <dir> <malicious_dir>"
echo "dir — the source directory with files to be restored"
echo "malicious_dir — directory where flagged/quarantined files are stored"
echo
exit 1
else
dir="$1"
malicious_dir="$2"
fi

white_list="$malicious_dir/white.list"
touch "$white_list" # create file if it doesn't exist

while true; do
    files=("$malicious_dir"/*)

    # # before adding the white list functionality
    # if [ "${files[0]}" == "$malicious_dir/*" ] # in practive if there are no files it returns the string "$malicious_dir/*"
    # then
    #     echo "No malicious files to review."
    #     exit 0
    # fi

    # after adding the white list functionality
    if [ "${#files[@]}" -eq 1 ] # only the white list file exists
    then
        echo "No malicious files to review."
        exit 0
    fi

    echo "Choose a file number to restore from the following list: (enter q to quit)"
    for ((i = 1 ; i <= ${#files[@]} ; i++)); do
        if [ "${files[$i-1]}" != "$white_list" ]; then # do not display the white list file
            echo "$i ${files[$i-1]##*/}"
        else
            white_list_index=$i
        fi
    done

    read -r choice

    if [[ "$choice" == "q" ]]; then
        echo "Exiting..."
        exit 0
    elif [[ "$choice" -eq "$white_list_index" ]]; then # if the user chooses the white list file
        echo "Invalid choice. Please enter a valid file number or 'q' to quit."
    elif [[ "$choice" -le ${#files[@]} && "$choice" -gt 0 ]]; then
        file_path="${files[$choice-1]}"
        echo "what do you want to do with the file: ${file_path##*/}"
        echo "Input 1: Restore this file back into dir (it was a false positive)"
        echo "Input 2: Permanently delete this file from malicious_dir (it was genuinely malicious)"
        echo "Input 3: Leave this file as-is and go back to the list"

        read -r action

        case "$action" in 
            "1")
                printf '%s %s\n' "$(date -r "${file_path}")" "${file_path##*/}" >> "$white_list" # add the restored file name + date modified to the white list
                mv "$file_path" "$dir"
                echo "Restored ${file_path##*/} to $dir."
                ;;
            "2")
                rm -f "$file_path"
                echo "${file_path##*/} permanently deleted."
                ;;
            "3")
                continue
                ;;
        esac
    else
        echo "Invalid choice. Please enter a valid file number or 'q' to quit."
    fi
done
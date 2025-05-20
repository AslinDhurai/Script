#!/bin/bash

now=$(date +%s)
output_file="inactive_users_3days.csv"
os_type=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')

echo "Username,Last Login Time,OS Type" > "$output_file"

users=$(awk -F: '$3 >= 1000 && $7 !~ /nologin/ { print $1 }' /etc/passwd)

for user in $users; do
    last_login=$(last -F -n 1 "$user" | grep -v "wtmp begins" | head -n 1)

    if [[ -z "$last_login" ]]; then
        echo "$user,Never logged in,$os_type" >> "$output_file"
    else
        login_time=$(echo "$last_login" | awk '{for(i=5;i<=8;++i) printf $i" "; print ""}' | xargs -I{} date -d "{}" +%s 2>/dev/null)

        if [[ ! "$login_time" =~ ^[0-9]+$ ]]; then
            echo "$user,Invalid date,$os_type" >> "$output_file"
            continue
        fi

        diff_days=$(( (now - login_time) / 86400 ))  # 86400 seconds in a day

        if [ "$diff_days" -gt 4 ]; then
            echo "$user,$(TZ='Asia/Kolkata' date -d "@$login_time"),$os_type" >> "$output_file"
        fi
    fi
done

echo " Users inactive for more than 3 days saved to $output_file"

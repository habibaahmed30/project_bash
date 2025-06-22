#!/usr/bin/bash

#ensures a directory exists, creating it if necessary
DB_DIR="databases"
mkdir -p "$DB_DIR"

# create database
function create_database() {
    while true; do
        read -p "Enter database name (letters, numbers, underscores only): " db_name
        
        # validation checks
        if [[ -z "$db_name" ]]; then
            echo "Database name cannot be empty!"
            continue
        fi
        
        if [[ ! "$db_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            echo "Invalid name! Use only letters, numbers, underscores, and start with a letter/_"
            continue
        fi
        
        if [[ "$db_name" == *" "* ]]; then
            echo "Database name cannot contain spaces!"
            continue
        fi
        
        if [ -d "$DB_DIR/$db_name" ]; then
            echo "Database '$db_name' already exists!"
            continue
        fi
        
        declare -a reserved_words=("ALL" "SELECT" "DELETE" "DROP" "CREATE")  # Add more as needed
        if [[ " ${reserved_words[@]} " =~ " ${db_name^^} " ]]; then
            echo "'$db_name' is a reserved word!"
            continue
        fi
        
        # all checks passed
        mkdir -p "$DB_DIR/$db_name"
        echo "Database '$db_name' created successfully!"
        break
    done
}

# show database
function show_databases() {
    
    # only list direct subdirectories of $DB_DIR (exclude $DB_DIR itself)
    db_list=$(find "$DB_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n")

    if [ -z "$db_list" ]; then
        echo "No databases found!"
        read -p "Press Enter to return to the main menu..."
    else
        echo "Available Databases:"
        echo "$db_list"
    fi
}

# drop database
function drop_database() {
    read -p "Enter database name to delete: " db_name
    if [ -d "$DB_DIR/$db_name" ]; then
        rm -rf "$DB_DIR/$db_name"
        echo "Database '$db_name' deleted successfully!"
    else
        echo "Database '$db_name' not found!"
    fi
}

# connect to database
function use_database() {
    read -p "Enter database name to use: " db_name
    if [ -d "$DB_DIR/$db_name" ]; then
        echo "Using database '$db_name'..."
        database_menu "$db_name"
    else
        echo "Database '$db_name' does not exist!"
    fi
}

function create_table() {
    while true; do
        # validate table name
        while true; do
            read -p "Enter table name (letters, numbers, underscores only): " table_name
            
            # check for empty input or space
            if [[ -z "$table_name" ]]; then
                echo "Error: Table name cannot be empty!"
                continue
            fi
            
            # check naming rules
            if [[ ! "$table_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                echo "Error: Invalid name! Use only letters, numbers, underscores, and start with a letter/_"
                continue
            fi
            
            # check if matches database name
            if [[ "$table_name" == "$1" ]]; then
                echo "Error: Table name cannot match database name!"
                continue
            fi
            
            # check reserved words
            declare -a reserved=("ALL" "SELECT" "WHERE" "INSERT" "UPDATE" "DELETE" "DROP" "CREATE")
            if [[ " ${reserved[@]} " =~ " ${table_name^^} " ]]; then
                echo "Error: '$table_name' is a reserved word!"
                continue
            fi
            
            # check if table already exists
            table_path="$DB_DIR/$1/$table_name"
            meta_path="$DB_DIR/$1/.$table_name-metadata"
            if [ -f "$table_path" ]; then
                echo "Error: Table '$table_name' already exists!"
                continue
            fi
            
            break
        done

        # enter and validate number of columns
        while true; do
            read -p "Enter number of columns (minimum 1): " col_num
            if [[ ! "$col_num" =~ ^[1-9][0-9]*$ ]]; then
                echo "Error: Please enter a valid number greater than 0"
            else
                break
            fi
        done

        pk_set=0  # PK flag
        
        # process each column
        for ((i=1; i<=col_num; i++)); do
            echo "── Column $i ──"
            
            # validate column name
            while true; do
                read -p "Enter column $i name: " col_name
                if [[ -z "$col_name" ]]; then
                    echo "Error: Column name cannot be empty!"
                elif [[ ! "$col_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                    echo "Error: Invalid column name! Use letters, numbers, underscores"
                else
                    break
                fi
            done
            
            # validate data type with full options
            while true; do
                read -p "Enter column $i datatype (int/float/bool/str): " col_type
                col_type=${col_type,,}  # Convert to lowercase
                
                case "$col_type" in
                    "int"|"float"|"bool"|"str")
                        break
                        ;;
                    *)
                        echo "Error: Invalid type! Choose from: int, float, bool, str"
                        ;;
                esac
            done
            
            line=""
           
            # primary key check (only for int columns)
            if (( pk_set == 0 )) && [[ "$col_type" == "int" ]]; then
                read -p "Make this column primary key? (y/n): " pk_check
                if [[ "${pk_check,,}" =~ ^y ]]; then
                    line+="pk|"
                    pk_set=1
                    col_type="id|int"  # special format for PK columns
                fi
            fi
            
            line+="${col_name}|${col_type}"
            echo "$line" >> "$meta_path"
        done
        
        # verify at least one primary key was selected
        if (( pk_set == 0 )); then
            echo "Warning: No primary key selected for table '$table_name'"
            read -p "Continue anyway? (y/n): " confirm
            if [[ ! "${confirm,,}" =~ ^y ]]; then
                rm -f "$meta_path"  # clean up metadata file
                continue
            fi
        fi
        
        touch "$table_path"
        echo "Table '$table_name' created successfully with $col_num columns!"
        break
    done
}

# list tables
function list_tables() {
    local db_path="$DB_DIR/$1"
    tables=$(ls -1 "$db_path" 2>/dev/null | grep -v '^\.')
    
    if [ -z "$tables" ]; then
        echo "No tables found in database '$1'!"
    else
        echo "Tables in database '$1':"
        echo "$tables"
    fi
    read -p "Press Enter to continue..."
}

# alter table BONUS
function alter_table() {
    
    # first: select the table need to be altered
    echo "Available tables in database '$1':"
    tables=$(ls "$DB_DIR/$1" | grep -v '^\.')  # skip hidden files (metadata)
    
    if [ -z "$tables" ]; then
        echo "No tables found!"
        return
    fi
    
    echo "$tables"
    read -p "Enter table name to alter: " table_name
    
    table_path="$DB_DIR/$1/$table_name"
    meta_path="$DB_DIR/$1/.$table_name-metadata"
    
    if [ ! -f "$table_path" ]; then
        echo "Error: Table '$table_name' doesn't exist!"
        return
    fi

    # second: alteration menu options
    while true; do
        echo "──────────────────────────────────"
        echo " Altering Table: $table_name"
        echo " 1) Add Column"
        echo " 2) Drop Column"
        echo " 3) Rename Column"
        echo " 4) Change Column Type"
        echo " 5) Back to Database Menu"
        echo "──────────────────────────────────"
        read -p "Choose operation (1-5): " choice

        case $choice in
            1)  # add column
		read -p "New column name: " col_name
                read -p "Data type (int/str): " col_type
    
                # validate input again
                if [[ -z "$col_name" ]]; then
        		echo "Error: Column name cannot be empty!"
    		elif [[ ! "$col_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        		echo "Error: Only letters, numbers, underscores allowed (start with letter/_)"
    		elif [[ ! "$col_type" =~ ^(int|str)$ ]]; then
        		echo "Error: Type must be 'int' or 'str'"
    		elif awk -F'|' '{print $1}' "$meta_path" | grep -q "^${col_name}$"; then
        		echo "Error: Column '$col_name' already exists!"
    		else
        	
        	# add to metadata file
        	echo "$col_name|$col_type" >> "$meta_path"
        	
        	# add empty values to existing rows
        	awk -F'|' -v OFS='|' '{print $0,""}' "$table_path" > tmp && mv tmp "$table_path"
        	echo "Column '$col_name' ($col_type) added successfully!"
    		fi
    		;;
                
            2)  # drop column
    table_path="$DB_DIR/$1/$table_name"
    meta_path="$DB_DIR/$1/.$table_name-metadata"

    # check if table exists first
    if [ ! -f "$table_path" ] || [ ! -f "$meta_path" ]; then
        echo "Error: Table or metadata not found!"
        return 1
    fi

    # show columns with PK 
    echo "Current columns:"
    awk -F'|' '{
        pk_marker = ($1 == "pk" || $1 == "id" || $2 ~ /id\|/) ? " [PRIMARY KEY]" : ""
        print NR")", $1, "(" ($2 ~ /\|/ ? substr($2, index($2, "|")+1) : $2) ")" pk_marker
    }' "$meta_path"

    # get column to drop
    while true; do
        read -p "Enter column number to drop: " col_num
        if [[ "$col_num" =~ ^[0-9]+$ ]] && (( col_num <= $(wc -l < "$meta_path") )); then
           
            # Check if that column is PK then warning if yes
            if awk -F'|' -v nr="$col_num" 'NR==nr && ($1 == "pk" || $1 == "id" || $2 ~ /id\|/) {exit 1}' "$meta_path"; then
                break
            else
                read -p "WARNING: This is a primary key column! Force drop? (y/n): " confirm
                [[ "${confirm,,}" == "y" ]] && break || continue
            fi
        else
            echo "Error: Invalid column number"
        fi
    done

    # confirm drop
    col_name=$(awk -F'|' -v nr="$col_num" 'NR==nr{print $1}' "$meta_path")
    read -p "Confirm drop column '$col_name'? (y/n): " confirm
    [[ "${confirm,,}" != "y" ]] && echo "Drop cancelled." && return 0

    # perform drop actually
    sed -i "${col_num}d" "$meta_path"
    awk -F'|' -v col="$col_num" -v OFS='|' '{
        for (i=1; i<=NF; i++) if (i != col) printf "%s%s", $i, (i<NF?OFS:"\n")
    }' "$table_path" > tmp && mv tmp "$table_path"
    
    echo "Column '$col_name' dropped successfully!"
    ;;
                
            3)  # rename column
                echo "Current columns:"
                awk -F'|' '{print NR")", $1, "("$2")"}' "$meta_path"
                
                read -p "Enter column number to rename: " col_num
                if [[ "$col_num" =~ ^[0-9]+$ ]] && (( col_num <= $(wc -l < "$meta_path") )); then
                    old_name=$(awk -F'|' -v nr="$col_num" 'NR==nr{print $1}' "$meta_path")
                    read -p "Enter new name for '$old_name': " new_name
                    
                    if [[ -n "$new_name" ]] && [[ ! "$new_name" =~ \| ]]; then
                       
                        # update metadata
                        awk -F'|' -v nr="$col_num" -v new="$new_name" 'BEGIN{OFS="|"} NR==nr{$1=new} {print}' \
                            "$meta_path" > tmp && mv tmp "$meta_path"
                        echo "Column renamed!"
                    else
                        echo "Error: Invalid name (cannot be empty or contain '|')"
                    fi
                else
                    echo "Error: Invalid column number"
                fi
                ;;
                
            4)  # change column type
		echo "Current columns:"
		awk -F'|' '{print NR")", $1, "("$2")"}' "$meta_path"

		read -p "Enter column number to change: " col_num
		if [[ "$col_num" =~ ^[0-9]+$ ]] && (( col_num > 0 && col_num <= $(wc -l < "$meta_path") )); then
		    col_name=$(awk -F'|' -v nr="$col_num" 'NR==nr{print $1}' "$meta_path")
		    old_type=$(awk -F'|' -v nr="$col_num" 'NR==nr{print $2}' "$meta_path")
		    
		    while true; do
			read -p "New type for '$col_name' (current: $old_type): " new_type
			
			if [[ -z "$new_type" ]]; then
			    echo "Error: Type cannot be empty"
			    continue
			fi
			
			if [[ "$new_type" == "$old_type" ]]; then
			    echo "Error: New type is the same as current type. No change needed."
			    break
			fi
			
			if [[ "$new_type" =~ ^(int|str)$ ]]; then
			   
			    # update metadata 
			    awk -F'|' -v nr="$col_num" -v new="$new_type" 'BEGIN{OFS="|"} NR==nr{$2=new} {print}' \
				"$meta_path" > tmp && mv tmp "$meta_path"
			    echo "Type changed from $old_type to $new_type!"
			    break
			else
			    echo "Error: Type must be 'int' or 'str'"
			fi
		    done
		else
		    echo "Error: Invalid column number. Must be between 1 and $(wc -l < "$meta_path")"
		fi
		;;
                
            5)  # exit
                break ;;
                
            *)
                echo "Invalid option!" ;;
        esac
        
        read -p "Press Enter to continue..."
    done
}

# table insertion
function insert_into_table() {
    
    # get table name
    read -p "Enter table name: " table_name
    
    # set file paths
    table_path="$DB_DIR/$1/$table_name"
    meta_path="$DB_DIR/$1/.$table_name-metadata"
    
    # check if table exists
    if [ ! -f "$table_path" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return 1
    fi

    # read column metadata
    columns=()
    types=()
    is_pk=()
    while IFS='|' read -r col_name col_type; do
        columns+=("$col_name")
       
        # checks if column is primary key by looking for "id|" pattern or column names "pk"/"id"
        base_type="${col_type##*|}" 
        types+=("$base_type")
       
        if [[ "$col_type" == *"id|"* || "$col_name" == "pk" || "$col_name" == "id" ]]; then
            is_pk+=(1)
        else
            is_pk+=(0)
        fi
    done < "$meta_path"

    # show table structure
    echo "Table structure:"
    paste <(printf "%s\n" "${columns[@]}") <(printf "%s\n" "${types[@]}") | column -t -s $'\t'
    
    # get next available PK (starts at 1 and increments)
    next_pk=1
    if [ -s "$table_path" ]; then
        pk_col=1
        for i in "${!columns[@]}"; do
            if (( is_pk[i] == 1 )); then
                pk_col=$((i+1))
                break
            fi
        done
        last_pk=$(cut -d'|' -f$pk_col "$table_path" | sort -n | tail -1)
        next_pk=$((last_pk + 1))
    fi

    # collect data for each column
    row_data=()
    for i in "${!columns[@]}"; do
        while true; do
           
            # suggest next PK value for PK columns
            if (( is_pk[i] == 1 )); then
                read -p "Enter value for ${columns[i]} (${types[i]}) [Suggested: $next_pk]: " value
                value="${value:-$next_pk}"  # use suggested value if empty
            else
                read -p "Enter value for ${columns[i]} (${types[i]}): " value
            fi
            
            # validate based on type of the column
            case "${types[i]}" in
                "int")
                    if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
                        echo "Error: ${columns[i]} must be an integer!"
                        continue
                    fi
                    
                    # additional validation for primary key
                    if (( is_pk[i] == 1 )); then
                      
                        # check if starts from 1
                        if (( value < 1 )); then
                            echo "Error: Primary key must be 1 or greater!"
                            continue
                        fi
                        
                        # check for duplicate primary key
                        if cut -d'|' -f$((i+1)) "$table_path" | grep -q "^${value}$"; then
                            echo "Error: Primary key value '$value' already exists!"
                            continue
                        fi
                    fi
                    ;;
                    
                "float")
                    if [[ ! "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
                        echo "Error: ${columns[i]} must be a float number!"
                        continue
                    fi
                    ;;
                    
                "bool")
                    value="${value,,}"  # convert to lowercase
                    if [[ ! "$value" =~ ^(true|false|0|1|yes|no)$ ]]; then
                        echo "Error: ${columns[i]} must be boolean (true/false/yes/no/0/1)"
                        continue
                    fi
                    # standardize to true/false
                    [[ "$value" =~ ^(1|yes)$ ]] && value="true"
                    [[ "$value" =~ ^(0|no)$ ]] && value="false"
                    ;;
                    
                "str")
                    if [[ -z "$value" ]]; then
                        echo "Error: ${columns[i]} cannot be empty!"
                        continue
                    fi
                    # Additional validation to ensure strings aren't just numbers
                    if [[ "$value" =~ ^[0-9]+$ ]]; then
                        echo "Warning: ${columns[i]} is a string field but you entered only numbers."
                        read -p "Are you sure you want to use '$value' as text (not a number)? [y/N]: " confirm
                        if [[ "${confirm,,}" != "y" ]]; then
                            continue
                        fi
                    fi
                    ;;
                    
                *)
                    echo "Error: Unknown type ${types[i]} for column ${columns[i]}"
                    return 1
                    ;;
            esac
            
            row_data+=("$value")
            break
        done
    done

    # Insert data (pipe-separated)
    echo "${row_data[*]}" | tr ' ' '|' >> "$table_path"
    echo "Data inserted successfully into '$table_name'"
}

# select from table
function select_from_table() {
    # get table name
    read -p "Enter table name: " table_name
    
    # set file paths
    table_path="$DB_DIR/$1/$table_name"
    meta_path="$DB_DIR/$1/.$table_name-metadata"
    
    # check if table exists
    if [ ! -f "$table_path" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return 1
    fi

    # check if metadata exists
    if [ ! -f "$meta_path" ]; then
        echo "Error: Metadata for table '$table_name' not found!"
        return 1
    fi

    # read column names from metadata
    columns=()
    while IFS='|' read -r col_name col_type; do
        columns+=("$col_name")
    done < "$meta_path"

    # display select options
    echo -e "\nSelect operation:"
    echo "1) Display all records"
    echo "2) Display specific columns"
    read -p "Enter your choice (1-2): " choice

    case $choice in
        1)
            # display all records with nice formatting
            echo -e "\nDisplaying all records from '$table_name':"
            (printf "%s|" "${columns[@]}" | sed 's/|$/\n/'; cat "$table_path") | column -t -s "|"
            ;;
        2)
            # show column selection
            echo -e "\nAvailable columns:"
            for i in "${!columns[@]}"; do
                echo "$((i+1))) ${columns[i]}"
            done

            # get column selection
            read -p "Enter column numbers to display (comma-separated): " col_nums
            IFS=',' read -ra selected_cols <<< "$col_nums"

            # validate column numbers
            valid_selection=true
            for col in "${selected_cols[@]}"; do
                if [[ ! "$col" =~ ^[0-9]+$ ]] || (( col < 1 )) || (( col > ${#columns[@]} )); then
                    echo "Error: Invalid column number '$col'"
                    valid_selection=false
                    break
                fi
            done

            if $valid_selection; then
                # awk command to display selected columns
                awk_cmd='BEGIN {FS="|"; OFS="|"} {print '
                for col in "${selected_cols[@]}"; do
                    awk_cmd+="\$$col,"
                done
                awk_cmd=${awk_cmd%,}'}'

                # display results
                echo -e "\nDisplaying selected columns from '$table_name':"
                (printf "%s|" "${columns[@]}" | sed 's/|$/\n/'; \
                 awk "$awk_cmd" "$table_path") | column -t -s "|"
            fi
            ;;

    esac
}

# update table
function update_table() {
    # get table name
    read -p "Enter table name: " table_name
    
    # Set file paths
    table_path="$DB_DIR/$1/$table_name"
    meta_path="$DB_DIR/$1/.$table_name-metadata"
    
    # check if table exists
    if [ ! -f "$table_path" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return 1
    fi

    # check if metadata exists
    if [ ! -f "$meta_path" ]; then
        echo "Error: Metadata for table '$table_name' not found!"
        return 1
    fi

    # read column metadata
     columns=()
     types=()
     while IFS='|' read -r col_name col_type; do
         columns+=("$col_name")
         # extract base type (handles cases like "id|int")
         base_type="${col_type##*|}"  # gets everything after last |
         types+=("$base_type")
     done < "$meta_path"

    # display table structure
    echo -e "\nTable structure:"
    paste <(printf "%s\n" "${columns[@]}") <(printf "%s\n" "${types[@]}") | column -t -s $'\t'

    # display first few records
    echo -e "\nFirst 5 records:"
    head -n 5 "$table_path" | column -t -s "|"
    
    echo -e "\nAvailable columns:"
    for i in "${!columns[@]}"; do
        echo "$((i+1))) ${columns[i]} (${types[i]})"
    done

    # now continue with column selection
    while true; do
        read -p "Enter column number to update: " col_num
        if [[ "$col_num" =~ ^[0-9]+$ ]] && (( col_num >= 1 )) && (( col_num <= ${#columns[@]} )); then
            break
        else
            echo "Error: Invalid column number. Please enter a number between 1 and ${#columns[@]}"
        fi
    done

    # get old value and verify it exists
    while true; do
        read -p "Enter current value to replace in column '${columns[col_num-1]}': " old_value
        
        # check if value exists in the specified column
        if ! awk -v col="$col_num" -v val="$old_value" 'BEGIN {FS="|"; found=0} 
            $col == val {found=1; exit} 
            END {exit !found}' "$table_path"; then
            echo "Error: The value '$old_value' was not found in column '${columns[col_num-1]}'"
            read -p "Would you like to try again? [y/N]: " retry
            if [[ "${retry,,}" != "y" ]]; then
                return 0
            fi
        else
            break
        fi
    done

    # get new value with validation
     while true; do
        read -p "Enter new value for '${columns[col_num-1]}' (${types[col_num-1]}): " new_value
        
        # validate based on column type
        case "${types[col_num-1]}" in
            "int")
                if [[ ! "$new_value" =~ ^-?[0-9]+$ ]]; then
                    echo "Error: ${columns[col_num-1]} must be an integer!"
                    continue
                fi
                ;;
            "float")
                if [[ ! "$new_value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
                    echo "Error: ${columns[col_num-1]} must be a float number!"
                    continue
                fi
                ;;
            "str")
                if [[ -z "$new_value" ]]; then
                    echo "Error: ${columns[col_num-1]} cannot be empty!"
                    continue
                fi
                # additional validation for string fields
                if [[ "$new_value" =~ ^[0-9]+$ ]]; then
                    echo "Warning: You're entering a number for a string field!"
                    read -p "Are you sure you want to use '$new_value' as text (not a number)? [y/N]: " confirm
                    if [[ "${confirm,,}" != "y" ]]; then
                        continue
                    fi
                fi
                ;;
            "bool")
                new_value="${new_value,,}"
                if [[ ! "$new_value" =~ ^(true|false|yes|no|1|0)$ ]]; then
                    echo "Error: ${columns[col_num-1]} must be boolean (true/false/yes/no/1/0)"
                    continue
                fi
                # standardize to true/false
                [[ "$new_value" =~ ^(yes|1)$ ]] && new_value="true"
                [[ "$new_value" =~ ^(no|0)$ ]] && new_value="false"
                ;;
            "date")
                if [[ ! "$new_value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || ! date -d "$new_value" >/dev/null 2>&1; then
                    echo "Error: Must be a valid date (YYYY-MM-DD)"
                    continue
                fi
                ;;
            *)
                echo "Error: Unknown type ${types[col_num-1]} for column ${columns[col_num-1]}"
                return 1
                ;;
        esac
        break
    done

    # confirm update
    read -p "Are you sure you want to replace '$old_value' with '$new_value' in column '${columns[col_num-1]}'? [y/N]: " confirm
    if [[ "${confirm,,}" != "y" ]]; then
        echo "Update cancelled."
        return 0
    fi

    # update with awk
    awk -v col="$col_num" -v old="$old_value" -v new="$new_value" '
        BEGIN {FS=OFS="|"; changed=0}
        {
            if ($col == old) {
                $col = new
                changed++
            }
            print
        }
        END {
            if (changed == 0) {
                print "Error: No records were updated" > "/dev/stderr"
                exit 1
            } else {
                print "Successfully updated", changed, "record(s)" > "/dev/stderr"
            }
        }
    ' "$table_path" > "$table_path.tmp" && mv "$table_path.tmp" "$table_path"

    # show updated records
    echo -e "\nUpdated records:"
    awk -v col="$col_num" -v old="$old_value" -v new="$new_value" '
        BEGIN {FS="|"; OFS="|"; print "--- Updated Records ---"}
        $col == new {print}
    ' "$table_path" | column -t -s "|"
}

# delete from table
function delete_from_table() {
    # get table name
    read -p "Enter table name: " table_name
    
    # set file paths
    table_path="$DB_DIR/$1/$table_name"
    meta_path="$DB_DIR/$1/.$table_name-metadata"
    
    # check if table exists
    if [ ! -f "$table_path" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return 1
    fi

    # check if metadata exists
    if [ ! -f "$meta_path" ]; then
        echo "Error: Metadata for table '$table_name' not found!"
        return 1
    fi

    # read column metadata
    columns=()
    types=()
    while IFS='|' read -r col_name col_type; do
        columns+=("$col_name")
        types+=("$col_type")
    done < "$meta_path"

    # display table structure and sample data
    echo -e "\nTable structure:"
    paste <(printf "%s\n" "${columns[@]}") <(printf "%s\n" "${types[@]}") | column -t -s $'\t'
    echo -e "\nFirst 5 records:"
    head -n 5 "$table_path" | column -t -s "|"

    # show column selection
    echo -e "\nAvailable columns:"
    for i in "${!columns[@]}"; do
        echo "$((i+1))) ${columns[i]} (${types[i]})"
    done

    # get column to search for deletion
    while true; do
        read -p "Enter column number to search for deletion: " col_num
        if [[ "$col_num" =~ ^[0-9]+$ ]] && (( col_num >= 1 )) && (( col_num <= ${#columns[@]} )); then
            break
        else
            echo "Error: Invalid column number. Please enter a number between 1 and ${#columns[@]}"
        fi
    done

    # get value to delete with validation
    read -p "Enter value to delete from column '${columns[col_num-1]}': " delete_value

    # count matching records
    matches=$(awk -F'|' -v col="$col_num" -v val="$delete_value" '$col == val {count++} END {print count+0}' "$table_path")

    if (( matches == 0 )); then
        echo "No records found matching '$delete_value' in column '${columns[col_num-1]}'"
        return 0
    fi

    # confirm deletion
    echo "Found $matches record(s) matching '$delete_value' in column '${columns[col_num-1]}'"
    read -p "Are you sure you want to delete these records? [y/N]: " confirm
    if [[ "${confirm,,}" != "y" ]]; then
        echo "Deletion cancelled."
        return 0
    fi

    # deletion with backup "SOFT DELETION"
    backup_path="$table_path.bak"
    cp "$table_path" "$backup_path"
    
    awk -F'|' -v col="$col_num" -v val="$delete_value" '$col != val' "$table_path" > "$table_path.tmp" && \
    mv "$table_path.tmp" "$table_path"

    # verify deletion
    new_count=$(awk -F'|' -v col="$col_num" -v val="$delete_value" '$col == val {count++} END {print count+0}' "$table_path")
    if (( new_count == 0 )); then
        echo "Successfully deleted $matches record(s)"
        # optionally keep backup or remove it
        # rm "$backup_path"
    else
        echo "Error: Failed to delete some records. Restoring backup..."
        mv "$backup_path" "$table_path"
        return 1
    fi
}

#soft delete, make a backup file for the table, for safty
function drop_table() {
    # get table name
    read -p "Enter table name to delete: " table_name
    
    # set file paths
    table_path="$DB_DIR/$1/$table_name"
    meta_path="$DB_DIR/$1/.$table_name-metadata"
    
    # check if table exists
    if [ ! -f "$table_path" ] && [ ! -f "$meta_path" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return 1
    fi

    # show confirmation prompt with table info
    echo -e "\nYou are about to permanently delete:"
    if [ -f "$table_path" ]; then
        echo "- Data file: $table_name"
        echo -n "Records: " 
        wc -l < "$table_path" | tr -d '\n'
        echo " (plus metadata)"
    fi
    
    # add extra warning for non-empty tables
    if [ -f "$table_path" ] && [ $(wc -l < "$table_path") -gt 0 ]; then
        echo -e "\n\033[31mWARNING: This table contains data!\033[0m"
    fi

    # final confirmation
    read -p "Are you absolutely sure you want to delete '$table_name'? [y/N]: " confirm
    if [[ "${confirm,,}" != "y" ]]; then
        echo "Table deletion cancelled."
        return 0
    fi

    # deletion with error handling
    errors=0
    if [ -f "$table_path" ]; then
        if ! rm "$table_path"; then
            echo "Error: Failed to delete data file"
            errors=1
        fi
    fi
    
    if [ -f "$meta_path" ]; then
        if ! rm "$meta_path"; then
            echo "Error: Failed to delete metadata file"
            errors=1
        fi
    fi

    # report results
    if [ $errors -eq 0 ]; then
        echo "Table '$table_name' was successfully deleted."
    else
        echo "Warning: Some components of '$table_name' may not have been fully deleted."
        return 1
    fi
}

# dealing with tables inside database
function database_menu() {
    local db_name="$1"
    while true; do
        echo "--------------------------------"
        echo "Using Database: $db_name"
        echo "1) Create Table"
        echo "2) List Tables"
        echo "3) Alter Table"
        echo "4) Insert into Table"
        echo "5) Select from Table"
        echo "6) Update Table"
        echo "7) Delete from Table"
        echo "8) Drop Table"
        echo "9) Back to Main Menu"
        echo "--------------------------------"
        read -p "Choose an option: " choice

        case $choice in
            1) create_table "$db_name" ;;
            2) list_tables "$db_name" ;;
            3) alter_table "$db_name" ;;
            4) insert_into_table "$db_name" ;;
            5) select_from_table "$db_name" ;;
            6) update_table "$db_name" ;;
            7) delete_from_table "$db_name" ;;
            8) drop_table "$db_name" ;;
            9) break ;;
            *) echo "Invalid option!" ;;
        esac
    done
}

# main menu
function main_menu() {
    while true; do
        echo "--------------------------------"
        echo "Simple Bash DBMS"
        echo "1) Create Database"
        echo "2) Show Databases"
        echo "3) Use Database"
        echo "4) Drop Database"
        echo "5) Exit"
        echo "--------------------------------"
        read -p "Choose an option: " choice

        case $choice in
            1) create_database ;;
            2) show_databases ;;
            3) use_database ;;
            4) drop_database ;;
            5) echo "Exiting..."; exit ;;
            *) echo "Invalid option!" ;;
        esac
    done
}

main_menu

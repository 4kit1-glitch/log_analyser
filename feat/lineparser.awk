BEGIN {
    FS = " "
    count = 0
}

{   
    
    # parse the lines
    if (NF == 0) next
    count++

    date=$1; time=$2;
    level=$3; gsub(/[\[\]]/, "", level);
    logger=$4; gsub(/:$/, "", logger);
    $1=$2=$3=$4="";
    sub(/^ +/, "");
    printf "%s|%s|%s|%s|%s\n", date, time, level, logger, $0
  
}
#!/bin/bash
#
export LANG="en_GB.UTF-8"
# ==========================================================================================
cloud_cp_gefs () {
  gcloud_bucket=$1
  gspath=$2
  files=$3
  DOUT=$4
  echo "Download from: $1/$2 the files: $3 . Saving in the $4"  
  #
  ## eval must be used to gsutil correctly expanding the list in the $files  {01..30}  
  eval "gsutil -qm cp gs://${gcloud_bucket}/${gspath}/$files $DOUT/"  
  #    -q is for quiet ; -m is for multiple file download in parallel
}
# ==========================================================================================
get_older_gefs () {
                        # Add ensemble members from previous forecast valid to the DANA date
  DANA=$1               # DANA        : date of analysis in YYYYMMDDHH format
  minusH=$2             # minusH      : hours before DANA to get more ensemble members
  members2add=$3        # members2add : number of ensemble members to add from that previous 
                        #               forecast, limited to GEFS/NCEP size (31: 00..30) 
  tot_ens=$4            # tot_ens     : number of members already downloaded.  
                        #               This is used to renumbering the added members
  out_dir=$5
  echo "Dirout = "$out_dir
  HH=${DANA:8:2}
# ===========================================================================================
  let last_num=$members2add
  list_ens=`echo "{01..$last_num}"`
  ## Get $members2add members (00..$last_num) from minusH h before DANA  
   lagYMDH=`date -u +%Y%m%d%H -d "${DANA:0:8} ${DANA:8:2} -${minusH} hours"`
   lagDYMD=${lagYMDH:0:8}
   lagHH=${lagYMDH:8:2}
   cloud_path='gefs.'${lagDYMD}/${lagHH}'/atmos'
   tmp_dir=${GEFSDATA}/tmp/${lagYMDH}
   mkdir -p ${tmp_dir}
   ## Build file names with wildcard *
   lagnm=`printf "%03d\n" $minusH`   ## pad with 0, so 6 => 006
   filesa='gep'${list_ens}'.t'${lagHH}'z.pgrb2a.0p50.f'${lagnm}
   filesb='gep'${list_ens}'.t'${lagHH}'z.pgrb2b.0p50.f'${lagnm}
   cloud_cp_gefs $gcloud_bucket $cloud_path/pgrb2ap5 $filesa $tmp_dir
   cloud_cp_gefs $gcloud_bucket $cloud_path/pgrb2bp5 $filesb $tmp_dir
   ## Rename the files changing f006 to f000 , adding 31 to member digit , and move the files to ${dirout}
   for i in  $(eval echo ${list_ens})  
   do
     add_ens=`echo $tot_ens+$i| bc`
     # echo "mv $tmp_dir/gep${i}.t${lagHH}z.pgrb2a.0p50.f${lagnm} ${out_dir}/gep${add_ens}.t${HH}z.pgrb2a.0p50.f000"
     mv $tmp_dir/gep${i}.t${lagHH}z.pgrb2a.0p50.f${lagnm} ${out_dir}/gep${add_ens}.t${HH}z.pgrb2a.0p50.f000
     mv $tmp_dir/gep${i}.t${lagHH}z.pgrb2b.0p50.f${lagnm} ${out_dir}/gep${add_ens}.t${HH}z.pgrb2b.0p50.f000
   done
   # remove diretório temporário
   # rm -r $tmp_dir
   ## let tot_ens=$tot_ens+$members2add
   echo "Now ensemble size is : "$tot_ens     ## in case of only echo of function is this, get the new ensemble size as 
   return $tot_ens   ## this only works if $tot_ens is in the range of exit status, i.e. 0 through 255 
}   

#  -------------------------------------------
#         MAIN  
#  -------------------------------------------
## Definições necessárias:
## NOTE: 2 files to be downloaded for GEFS :
              #   gs://gfs-ensemble-forecast-system/gefs.20241009/12/atmos/pgrb2bp5/gep{01..30}.t12z.pgrb2b.0p50.f000
              #   gs://gfs-ensemble-forecast-system/gefs.20241009/12/atmos/pgrb2ap5/gep{01..30}.t12z.pgrb2a.0p50.f000

site='https://nomads.ncep.noaa.gov/pub/data/nccf/com/gens/prod'    
gcloud_bucket='gfs-ensemble-forecast-system'
#                                                                                          
#  Open read and listing permition for other 
umask 0022    #  drwxr-xr-x  for new directories ;  -rw-r--r--  for new files

# --------------------------------------
#

if [ $# -eq 0 ]
  then
    DYMD=`date -u +%Y%m%d`
    echo "No arguments supplied, system date: "${DYMD}
    hh=`date -u +%H `
    HREF='14'
    if [ "$hh" \< "$HREF" ]; then
        HH='00'
    else
        HH='12'
    fi
    echo 'Hora local: '$hh'   Processar arquivos de : '${DYMD}'  '${HH}'z'

    YMDH=${DYMD}${HH}
else
    YMDH=$1
    DYMD=${YMDH:0:8}
    HH=${YMDH:8:2}
    echo "Arguments supplied, date: "$DYMD
    echo ' Processar arquivos de : '${DYMD}'  '${HH}'z'
fi

date  ### To infer the time to downloading

. setenv.bash

YY=${YMDH:0:4}
MM=${YMDH:4:2}
DD=${YMDH:6:2}

cloud_path='gefs.'${DYMD}/${HH}'/atmos'

export dirout=${GEFSDATA}/${YY}/${MM}/${DD}/${HH}
mkdir -p ${dirout}

## Each date GEFS has 30 members .
EnsSize=80
# 30 members of analysis ; 
# 30 members of 06h forecast from previous analysis time ; separated temporary directory ; them mv arranging the name of files
# + 20 members of 12h forecast from analysis 12 hours before


## Build file names with wildcard *
filesa='gep{01..30}.t'${HH}'z.pgrb2a.0p50.f000'
filesb='gep{01..30}.t'${HH}'z.pgrb2b.0p50.f000'

## Get first 30 members (01..30) from YMDH GEFS run
echo cloud_cp_gefs $gcloud_bucket $cloud_path/pgrb2ap5 $filesa $dirout
cloud_cp_gefs $gcloud_bucket $cloud_path/pgrb2ap5 $filesa $dirout
cloud_cp_gefs $gcloud_bucket $cloud_path/pgrb2bp5 $filesb $dirout
tot_ens=30

## get more 31 members from 6 hours before
get_older_gefs $YMDH 6 30 $tot_ens $dirout
let tot_ens=$tot_ens+30


## get more 18 members from 12 hours before
echo to_add=$EnsSize-$tot_ens
let to_add=$EnsSize-$tot_ens     # 80 - 60 = 20
echo "Now to_add = "$to_add
get_older_gefs $YMDH 12 $to_add $tot_ens $dirout
let tot_ens=$tot_ens+$to_add

echo "Arquivos disponíveis em : "${dirout}
ls ${dirout}

date

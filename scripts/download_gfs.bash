#!/bin/bash
#
export LANG="en_GB.UTF-8"

get_gfs_rda () {
  echo "Download from: $1 file: $2"
  wget $1/$2

}


#
#  Definições necessárias:
#  3) extensão da previsão em horas FCE (ex.: 72 , 240 )
#  4) caminho do output (ex.: /mnt/beegfs/${USER}/jedi/suite/datain/GFS )
#
#
site='https://data.rda.ucar.edu/d084001'

# --------------------------------------
#
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

    DATA=${DYMD}${HH}
else
    DATA=$1
    DYMD=${DATA:0:8}
    HH=${DATA:8:2}
    echo "Arguments supplied, date: "$DYMD
    echo ' Processar arquivos de : '${DYMD}'  '${HH}'z'
fi

. setenv.bash

# dirout=${HOME}/gfsCI/${DATA}
YY=${DATA:0:4}
MM=${DATA:4:2}
DD=${DATA:6:2}

operdir_out=$OPERDIR/GFS/0p25/brutos/${YY}/${MM}/${DD}/${HH}
dirout=${GFSDATA}/${YY}/${MM}/${DD}/${HH}

mkdir -p ${dirout}

# create temporary directory to work on
tmpdir=tmp${DATA}

mkdir -p ${tmpdir}
cd ${tmpdir}

fctint=3
FCI=0
FCE=0   # Adjust FCE to the lenght (in hours) of your REGIONAL experiment
        # to produce lateral boundary condition 

sizeok=500000000   ## Minimum size for GFS forecast 000 hours file.
                   ## download it if local file smaller than this.

### Get Forecasts ----------------

while (($FCI<=$FCE)) ; do

  fchh=`printf "%03d" $FCI`

  DVALID=`date -u +%Y%m%d%H -d "${DATA:0:8} ${DATA:8:2} +${FCI} hours"`

# Ex.:   2024/20240921/gfs.0p25.2024092100.f003.grib2
#
# path date pattern:   YYYY/YYYYMMDD
  pathdate=${YY}'/'${DYMD}

  fname='gfs.0p25.'${DYMD}${HH}'.f'${fchh}'.grib2'
  fname_oper='gfs.t'${HH}z.pgrb2.0p25.f${fchh}'.'${DYMD}${HH}'.grib2'

  PATHFILE=${pathdate}'/'${fname}
  ## possible file already available in operation area
  file_oper=${operdir_out}'/'${fname_oper}
  if [ -f "$file_oper" ]; then  # 
       # Get file size
     FSIZE_OPER=$(stat -c%s "$file_oper")
  fi
  ## possible already downloaded file
  file_already=${dirout}/${fname}
  if [ -f "$file_already" ]; then  # 
       # Get file size
     FSIZE_already=$(stat -c%s "$file_already")
  fi
  if ([ -f "$file_already" ] && [ "$FSIZE_already" -ge "$sizeok" ]) ; then
     # Get file size
        
     ## if (( FSIZE_already > sizeok )) ; then
        echo "File  $file_already already there, so not downloading it ..."
        echo "If $file_already is not ok, remove it, then try this script again." 
     ## fi
  elif ([ -f "$file_oper" ] && [ "$FSIZE_OPER" -ge "$sizeok"]); then  # 
       # Get file size
     FILESIZE=$(stat -c%s "$file_oper")     
     # if (( FILESIZE > sizeok )) ; then
        echo "Copying $file_oper ..."
        cp $file_oper ${dirout}/$fname
     # fi
  else 
      ### Make it as a function
      echo "$fname not on OPER disk. Downloading it from RDA/UCAR ..."
      get_gfs_rda $site $PATHFILE 
      mv ${fname} ${dirout}/.
  fi
  
  if(($FCI<120)) ; then
    let FCI=$FCI+$fctint
  elif(($FCI<240)) ; then
    let FCI=$FCI+3
  else
    let FCI=$FCI+12
  fi

  ANO=${DATA:0:4}
  MES=${DATA:4:2}
  DIA=${DATA:6:2}
  HORA=${DATA:8:2}

  DATAF=${DATA}
  unset ANO
  unset MES
done

echo "Arquivos disponíveis em : "${dirout}
ls ${dirout}
# volta ao diretório de onde foi chamado
cd ..
# remove diretório temporário
rm -r ${tmpdir}


#!/bin/bash
#-----------------------------------------------------------------------------#
#           Group on Data Assimilation Development - GDAD/CPTEC/INPE          #
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: gerar conjunto de previsoes com o MPAS 8.2 para uso no 3DenVAR 
#
# !DESCRIPTION: A partir de membros do GEFS/NOAA, cria condiçoes iniciais para 
#               o MPAS, que gera um conjunto de previsões.
#               As previsões (backgrounds) são usadas pelo BUMP para parametrizar 
#               a matriz de covariância de erros da previsão usada no 3DenVar.
#               O conjunto de first guess gerado também pode ser usado para iniciar
#               um ciclo de assimilação/previsão por Ensemble (EDA, LETKF) ou para uso
#               no Hibrid-En-3dVar   
#
# !CALLING SEQUENCE:
#
#   ./run_MPAS-ensemble.sh <opções>
#
#      As <opções> válidas são
#          * -ci   <val> : origem da condição inicial [default: GFSENS]
#          * -res  <val> : numero de pontos da resolução de grade [default: 256002 para 48km]  
#          * -I    <val> : Data da condição inicial do ciclo
#          * -freq <val> : frequência de saída de background (first guess) [default: each 6 hours] 
#          * -fct  <val> : Numero de horas de previsão [default: 12 hours]
#          * -esize <val>: Número de membros do conjunto [default: 80 membros]
#          * -h          : Mostra este help
#
#          exemplo:
#          ./run_MPAS-ensemble.sh -ci GEFS -res 256002 -I 2024070100 -freq 6 -fct 12
#
# !REVISION HISTORY:
# 11 Oct 2024 - Aravequia, J. A. - Initial Version based on run_MPAS-periodo.sh 
# 
# !REMARKS:
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

#-----------------------------------------------------------------------------#
# Carregando as variaveis do sistema

subwrd() {
   str=$(echo "${@}" | awk '{ for (i=1; i<=NF-1; i++) printf("%s ",$i)}')
   n=$(echo "${@}" | awk '{ print $NF }')
   echo "${str}" | awk -v var=${n} '{print $var}'
}

#-----------------------------------------------------------------------------#
# return usage from main program
#-----------------------------------------------------------------------------#
usage() {
   echo
   echo "Usage:"
   sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}

i=1
flag=0
while true; do

   arg=$(echo "${@}" | awk -v var=${i} '{print $var}')
   i=$((i+1))

   if [ -z ${arg} ]; then break; fi

   while true; do
      # model options
      if [ ${arg} = '-ci' ]; then exp=$(subwrd ${@} ${i}); i=$((i+1));  break; fi
      if [ ${arg} = '-res' ]; then res=$(subwrd ${@} ${i}); i=$((i+1));  break; fi
      # general options
      if [ ${arg} = '-I' ];     then LABELI=$(subwrd ${@} ${i}); i=$((i+1));   break; fi
      if [ ${arg} = '-freq' ];  then freqbg=$(subwrd ${@} ${i}); i=$((i+1));   break; fi
      if [ ${arg} = '-fct' ];   then modelFCT=$(subwrd ${@} ${i}); i=$((i+1)); break; fi
      if [ ${arg} = '-esize' ]; then Esize=$(subwrd ${@} ${i}); i=$((i+1));    break; fi
      flag=1
      i=$((i-1))

      break
   done

   if [ ${flag} -eq 1 ]; then break; fi

done

# Truncamento do background
if [ -z ${exp} ]; then
   echo -e "\e[31;1m >> Warning: \e[m\e[33;1m Faltou o argumento (-ci) para a fonte da Condição Inicial\e[m"
   echo -e "Usando o Default : GFSENS"
   echo " "
   exp='GFSENS'
fi

# Numero de niveis do background
if [ -z ${res} ]; then
   echo -e "\e[33;1m >> Warning: \e[m\e[33;1m Faltou o argumento (-res) para a definir a grade \e[m"
   echo -e "Usando o Default : 256002 para usar resolução de grade de 48km"
   echo " "
   res=256002
fi

# Data inicial da rodada
if [ -z ${LABELI} ]; then
   echo -e "\e[31;1m >> Erro: \e[m\e[33;1m A data inicial não foi passada\e[m"
   usage
   exit -1
fi

# Frequencia de arquivos de background (first guess)
if [ -z ${freqbg} ]; then
   echo -e "\e[33;1m >> Warning: \e[m\e[33;1m Frequencia (-freq NUM) não informada.  \e[m"
   echo -e "Usando default : 6 para saídas a cada 6 horas" 
   echo " " 
   freqbg=6
fi

# Estenção da previsão em Horas
if [ -z ${modelFCT} ]; then
   echo -e "\e[33;1m >> Warning: \e[m\e[33;1m Extensão da previsão (-fct) não informada\e[m"
   echo -e "Usando default : previsão irá até 12 horas" 
   echo " " 
   modelFCT=12
fi

# Número de membros do Ensemble
if [ -z ${Esize} ]; then
   echo -e "\e[33;1m >> Warning: \e[m\e[33;1m Número de membros do ensemble (-esize) não informado\e[m"
   echo -e "Usando default : 80 membros" 
   echo " " 
   Esize=80
fi

# Não haverá modificações na coordenada vertical
export gsiNLevs=${modelNLevs}

echo -e ""
echo -e "\033[34;1m CONFIGURACAO DA RODADA \033[m"
echo -e ""
echo -e "\033[34;1m > Resolucao do Modelo : \033[m \033[31;1m${res}\033[m"
echo -e "\033[34;1m > Condição Inicial    : \033[m \033[31;1m${exp}\033[m"
echo -e "\033[34;1m > Data Inicial        : \033[m \033[31;1m${LABELI}\033[m"
echo -e "\033[34;1m > Freq. de saídas (h) : \033[m \033[31;1m${freqbg}\033[m"
echo -e "\033[34;1m > Tempo de Previsao   : \033[m \033[31;1m${modelFCT}\033[m"
echo -e "\033[34;1m > Membros do Ensemble : \033[m \033[31;1m${Esize}\033[m"

. setenv.bash

# Download GEFS initial condition from NOAA cloud bucket
./download_gefs.bash ${LABELI}

sizeok=6300000    ## typical size of dataout/yyyymmddhh directory is 6391784 Kb (6.1 Gb)

dirout=${DIR_DADOS}/dataout/${LABELI}
mkdir -p $dirout                       # next verification needs it to be created   

size_dout=`\du -s $dirout | cut -f 1`
echo ""
echo -e "\033[34;1m >>> Submetendo o Sistema para o dia \033[31;1m${LABELI}\033[m \033[m"
echo ""

# using WRF/WPS ungrib.exe app, degrig GFS Initial condition
## ens_degrib.bash EXP_NAME RESOLUTION LABELI FCST [Esize]
./ens_degrib.bash ${exp} ${res} ${LABELI} ${modelFCT} ${Esize}

# convert Initial condition into the MPAS grid
## ./ens_make_initatmos.bash EXP_NAME RESOLUTION LABELI FCST [Esize]
./ens_make_initatmos.bash ${exp} ${res} ${LABELI} ${modelFCT} ${Esize}

# run MPAS 
## ens_run_model.bash EXP_NAME RESOLUTION LABELI FCST [Esize]
echo -e "./ens_run_model.bash ${exp} ${res} ${LABELI} ${modelFCT} ${Esize}" 
./ens_run_model.bash ${exp} ${res} ${LABELI} ${modelFCT} ${Esize}

size_dout=`\du -s $dirout | cut -f 1`   # Get the size of output directory to verify it is runned OK

#EOC
#-----------------------------------------------------------------------------#

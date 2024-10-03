#!/bin/bash
#-----------------------------------------------------------------------------#
#           Group on Data Assimilation Development - GDAD/CPTEC/INPE          #
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: gerar previsoes com o MPAS 8.2 para construir matriz B
#
# !DESCRIPTION:
#
# !CALLING SEQUENCE:
#
#   ./run_MPAS-periodo.sh <opções>
#
#      As <opções> válidas são
#          * -ci   <val> : origem da condição inicial [default: GFS]
#          * -res  <val> : numero de pontos da resolução de grade [default: 256002 para 48km]  
#          * -I    <val> : Data da primeira condição inicial do ciclo
#          * -F    <val> : Data da útima condição inicial do ciclo
#          * -fct  <val> : Numero de horas de previsão [default: 48]
#          * -h          : Mostra este help
#
#          exemplo:
#          ./run_MPAS-periodo.sh -ci GFS -res 256002 -I 2024070100 -F 2024093018 -fcst 48
#
# !REVISION HISTORY:
# 02 Oct 2024 - Aravequia, J. A. - Initial Version based on script run_cycle.sh 
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
      if [ ${arg} = '-I' ];   then LABELI=$(subwrd ${@} ${i}); i=$((i+1));   break; fi
      if [ ${arg} = '-F' ];   then LABELF=$(subwrd ${@} ${i}); i=$((i+1));   break; fi
      if [ ${arg} = '-fct' ]; then modelFCT=$(subwrd ${@} ${i}); i=$((i+1)); break; fi
      flag=1
      i=$((i-1))

      break
   done

   if [ ${flag} -eq 1 ]; then break; fi

done

# Truncamento do background
if [ -z ${exp} ]; then
   echo -e "\e[31;1m >> Warning: \e[m\e[33;1m Faltou o argumento (-ci) para a fonte da Condição Inicial\e[m"
   echo -e "Usando o Default : GFS"
   echo " "
   exp='GFS'
fi

# Numero de niveis do background
if [ -z ${res} ]; then
   echo -e "\e[31;1m >> Warning: \e[m\e[33;1m Faltou o argumento (-res) para a definir a grade \e[m"
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

# Data final da rodada
if [ -z ${LABELF} ]; then
   echo -e "\e[31;1m >> Erro: \e[m\e[33;1m A data Final não foi passada\e[m"
   usage
   exit -1
fi

# Estenção da previsão em Horas
if [ -z ${modelFCT} ]; then
   echo -e "\e[31;1m >> Erro: \e[m\e[33;1m O argumento para definir quantas horas de previsão (-fct) não foi passado\e[m"
   usage
   exit -1
fi


# Não haverá modificações na coordenada vertical
export gsiNLevs=${modelNLevs}

echo -e ""
echo -e "\033[34;1m CONFIGURACAO DA RODADA \033[m"
echo -e ""
echo -e "\033[34;1m > Resolucao do Modelo : \033[m \033[31;1m${res}\033[m"
echo -e "\033[34;1m > Condição Inicial    : \033[m \033[31;1m${exp}\033[m"
echo -e "\033[34;1m > Data Inicial        : \033[m \033[31;1m${LABELI}\033[m"
echo -e "\033[34;1m > Data Final          : \033[m \033[31;1m${LABELF}\033[m"
echo -e "\033[34;1m > Tempo de Previsao   : \033[m \033[31;1m${modelFCT}\033[m"



while [ ${LABELI} -le ${LABELF} ]; do
   

   echo ""
   echo -e "\033[34;1m >>> Submetendo o Sistema para o dia \033[31;1m${LABELI}\033[m \033[m"
   echo ""

   # find GFS initial condition in the system file or download it from RDA/UCAR
   ./download_gfs.bash ${LABELI}

   # using WRF/WPS ungrib.exe app, degrig GFS Initial condition
   ./make_degrib.bash ${exp} ${res} ${LABELI} ${modelFCT} 

   # convert Initial condition into the MPAS grid
   ./make_initatmos.bash ${exp} ${res} ${LABELI} ${modelFCT}

   # run MPAS 
   ./3.run_model.bash ${exp} ${res} ${LABELI} ${modelFCT}


   #    Going to the next analysis time
   LABELI=`date -u +%Y%m%d%H -d "${LABELI:0:8} ${LABELI:8:2} +6 hours" ` 

done

#EOC
#-----------------------------------------------------------------------------#

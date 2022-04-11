
# countries to do by default, or just one if given on command line

# 2022-04-11 removed hungary - turns out it was added in error
# ["hu"]="Hungary" \

declare -A COUNTRY_NAMES=(\
               ["at"]="Austria" \
               ["be"]="Belgium" \
               ["br"]="Brazil" \
               ["ca"]="Canada" \
               ["ch"]="Switzerland" \
               ["cz"]="Czechia" \
               ["de"]="Germany" \
               ["dk"]="Denmark" \
               ["ec"]="Ecuador" \
               ["ee"]="Estonia" \
               ["es"]="Spain" \
               ["fi"]="Finland" \
               ["gu"]="Guam" \
               ["hr"]="Croatia" \
               ["ie"]="Ireland" \
               ["it"]="Italy" \
               ["lv"]="Latvia" \
               ["mt"]="Malta" \
               ["nl"]="Netherlands" \
               ["pl"]="Poland" \
               ["pr"]="Puerto Rico" \
               ["pt"]="Portugal" \
               ["si"]="Slovenia" \
               ["ukenw"]="England and Wales" \
               ["ukgi"]="Gibraltar" \
               ["ukni"]="Northern Ireland" \
               ["uksc"]="Scotland" \
               ["usva"]="Virginia" \
               ["usal"]="Alabama" \
               ["usde"]="Delaware" \
               ["usnv"]="Nevada" \
               ["uswy"]="Wyoming" \
               ["za"]="South Africa" \
           )

COUNTRY_LIST=`echo "${!COUNTRY_NAMES[@]}" | tr ' ' '\n' | sort | tr '\n' ' '`


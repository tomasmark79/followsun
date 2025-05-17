# vypočítá velikost oddílu v MiB
blocks=$(sudo resize2fs -P /dev/mapper/vg_main-lv_root | awk '{print $NF}')
size_bytes=$(( blocks * 4096 ))
size_mib=$(( (size_bytes + 104857599) / 104857600 * 100 ))  # zaokrouhleno na celé stovky MB
echo "${size_mib}M"


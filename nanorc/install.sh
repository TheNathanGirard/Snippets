NANORC_FILE=~/.nanorc

_copy_source(){
  echo "Runnning _copy_source"
  mkdir -p ~/.nano/
  cp *.nanorc ~/.nano
}

echo "Starting"

echo "set autoindent" | tee .nanorc
echo "set tabstospaces" | tee -a .nanorc
echo "set tabsize 2" | tee -a .nanorc

for i in `find ~/.nano/ -name "*.nanorc" -type f`; do
  echo 'include "'$i'"' | tee -a .nanorc
done

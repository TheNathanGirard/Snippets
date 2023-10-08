NANORC_FILE=~/.nanorc

_copy_source(){
  echo "Runnning _copy_source"
  mkdir -p ~/.nano/
  cp *.nanorc ~/.nano
}



echo "Starting"
_copy_source


echo "set autoindent" | tee $NANORC_FILE
echo "set tabstospaces" | tee -a $NANORC_FILE
echo "set tabsize 2" | tee -a $NANORC_FILE

for i in `find ~/.nano/ -name "*.nanorc" -type f`; do
  echo 'include "'$i'"' | tee -a $NANORC_FILE
done

for var in "$@"
do
  echo "$var" >> /tmp/aria
done

aria2c -s 16 -j8 -x4 -c -i /tmp/aria

rm /tmp/aria

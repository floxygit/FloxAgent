#!/bin/sh

clear
echo "Loading..."
sleep 1
apt update
clear
echo "Installing wget and curl."
sleep 1
apt install curl wget -y
clear

while :
do
  echo "FloxAgent V1.0 Menu"
  echo
  echo "[1] Providers"
  echo "[0] Exit"
  printf "Auswahl: "
  read -r choice
  case "$choice" in
    1)
      clear
      ;;
    0)
      exit 0
      ;;
    *)
      clear
      ;;
  esac
done

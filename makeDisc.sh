
if [ ! -f "disc/drock.d64" ]; then
  mkdir -p disc
  c1541 -format puyo,sk d81 disc/puyo.d81
fi

c1541 <<EOF
attach disc/puyo.d81
delete kpuyo.prg
write kpuyo.prg
EOF





# kickc.sh -a ./kpuyo.c -Ocoalesce

if [ ! -f "disc/kpuyo.d64" ]; then
  mkdir -p disc
  c1541 -format kpuyo,sk d81 disc/kpuyo.d81
fi

c1541 <<EOF
attach disc/kpuyo.d81
delete kpuyo.prg
write kpuyo.prg
EOF

xc65.native -8 disc/kpuyo.d81 -go64



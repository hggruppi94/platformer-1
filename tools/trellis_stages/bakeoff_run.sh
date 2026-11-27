# bakeoff/run.sh <backend>: runs one generator on bakeoff/in/front.png (+ side, back) with VRAM sampled every second
B=$1; O=/c/Users/hggru/Game_dev/ai3d/bakeoff/$B; mkdir -p $O; rm -f $O/vram.txt
base=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
(while true; do nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits >> $O/vram.txt; sleep 1; done) & P=$!
python /c/Users/hggru/Game_dev/pf1-ai-rebuild/tools/trellis_stages/trellis.py /c/Users/hggru/Game_dev/ai3d/bakeoff/in/front.png $O $B 2>&1 | tail -4
kill $P
peak=$(sort -n $O/vram.txt | tail -1)
echo "$B before $base MB, peak $peak MB" | tee $O/vram_summary.txt

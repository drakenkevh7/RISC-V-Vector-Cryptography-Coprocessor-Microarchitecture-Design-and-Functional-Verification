run:
	./sim/run_verilator.sh

clean:
	rm -rf sim/obj_dir obj_dir
	rm -f tb/generated_aes_*.txt tb/generated_vl_*.txt

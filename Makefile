SHELL=/bin/bash

aggregate: convert_times.go
	for subj in 1 2 3 4 5 6 7 8 9 10 11 12 13; do \
		go run convert_times.go -s $$subj; \
	done

clean:
	rm log.txt output/*
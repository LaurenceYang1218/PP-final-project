CXX = g++
CFLAGS = -O2 -std=c++17

.PHONY: all run clean

all: dijkstra bellmanford

dijkstra: dijkstra_serial.cc
	$(CXX) $(CFLAGS) $< -o $@ 

bellmanford: BellmanFord_serial.cc
	$(CXX) $(CFLAGS) $< -o $@

clean: 
	rm dijkstra
	rm bellmanford
	
run_dijkstra: 
	./dijkstra ./output.txt 100 500

run_bellmanford:
	./bellmanford ./output.txt 100 500
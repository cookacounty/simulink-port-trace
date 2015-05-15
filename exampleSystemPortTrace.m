sp = SystemPortTrace();

%% Inport
hBlock = 'tb_dig_top/dig_top/dig_simulink/sl_in';
sp.tracePort(hBlock,'back');
sp.dispResults()

%% Outport
hBlock = 'tb_dig_top/dig_top/dig_simulink/sl_out';
sp.tracePort(hBlock,'forward');
sp.dispResults()


%% System
hBlock = 'tb_dig_top/dig_top/dig_simulink';
sp.traceSystem(hBlock);
sp.dispResults()
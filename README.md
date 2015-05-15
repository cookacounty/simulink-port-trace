# simulink-port-trace
Trace Ports Programatically through a Simulink Design

Unlink the built in commands, simulink-port-trace will expand busses and find the driver
for each signal in the bus.

The user can specify the blocks to stop the trace on. The result returned is a table
showing the location of the final source/sink the trace ended on.

The end goal for my particular application was to automatically generate a table that described where
the inputs/outputs of my block were being driven from in the design

Below is an example use case:

```matlab
stopBlocks.type   = {
    'Constant', ...
    'Constant', ...
    'Inport', ...
    'Outport'
    };
stopBlocks.parent = {
    'tb_dig_top/dig_top_1720/dig_rtl/volitile', ...
    'tb_dig_top/dig_top_1720/dig_rtl/eeprom', ...
    'tb_dig_top/dig_top_1720', ...
    'tb_dig_top/dig_top_1720'
    };

sp = SystemPortTrace(stopBlocks);
sp.verbose = 0;
sp.traceSystem('tb_dig_top/dig_top_1720/dig_matlab');
```

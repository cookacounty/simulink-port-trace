classdef SystemPortTrace < handle
    %% SystemPortTrace - A class for tracing the src/dst of a port(s)
    % in a system. It is specifically designed to stop at defined
    % block types/ block paths and report the name
    
    %#ok<*PROP>
    %#ok<*MATCH2>
    
    properties
        hBlock;
        tDir;
        stopBlocks;
        verbose = 0;
        busNames = {}; %Names of valid busses
        results = {}
    end
    methods
        function obj = SystemPortTrace(stopBlocks)
            %% SYSTEMPORTTRACE() Create a new object for tracing system ports
            % SYSTEMPORTTRACE(stopBlocks) - specify custom stop block rules
            %
            % Format for stop blocks is a struct with cell arrays of the
            % Each type should have a corresponding parent.
            %
            % TODO: A parent of '' means any parent will cause a stop.
            %
            % For example:
            %   stopBlocks.type   = {'Constant','Inport'}
            %   stopBlocks.parent = {'mysys1','mysys1/subsystem'}
            
            if ~exist('stopBlocks','var')
                % Default Stop Blocks
                obj.stopBlocks.type   = {'Constant',                          'Inport',             'Outport'};
                obj.stopBlocks.parent = {'tb_dig_top/dig_top/dig_rtl/ids_top','tb_dig_top/dig_top', 'tb_dig_top/dig_top'};
            else
                obj.stopBlocks = stopBlocks;
            end
        end
        function tracePort(obj,hBlock,tDir)
            %% TRACEPORT(hBlock,tDir,busNames))
            %  Trace a system's ports to their source/dst
            %
            % hBlock - The hierarctical name of port to trace
            % tDir   - The direction of the trace ('forward','backward')
            
            %% Input Validation
            
            %Check that the input is a port
            bType = get_param(hBlock,'BlockType');
            if ~any(strcmp(bType,{'Inport','Outport'}))
                error('Block %b must be an Inport or Outport', hPort)
            end
            
            
            %Determine trace direction
            if strmatch('b',lower(tDir))
                obj.tDir = 'backward';
            elseif strmatch('f',lower(tDir))
                obj.tDir = 'forward';
            end
            % Save data into class
            obj.hBlock = hBlock;
            
            %% Run trace
            obj.run();
        end
        
        %% Trace all ports in a system
        function traceSystem(obj,systemName)
            
            portDirs = {'Inport','Outport'};
            
            for portDir = portDirs
                portDir = portDir{:};
                switch portDir
                    case 'Inport'
                        traceDir = 'backward';
                    case 'Outport'
                        traceDir = 'forward';
                end
                
                ports = find_system(systemName,'SearchDepth',1,'FollowLinks','on','BlockType',portDir);
                if isempty(ports)
                    error('Could not find any %s in system %s',ports,systemName);
                end
                
                for port = ports'
                    port = port{:};
                    if obj.verbose; fprintf('Begin Trace on Port %s\n',port); end;
                    obj.tracePort(port,traceDir);
                end
            end
            
        end
        
        function run(obj)
            %% Run the script
            
            switch obj.tDir
                case 'backward'
                    pType = 'Outport';
                case 'forward'
                    pType = 'Inport';
            end
            
            pHandles = get_param(obj.hBlock,'PortHandles');
            hPort = pHandles.(pType);
            hBus = get_param(hPort,'SignalHierarchy');
            
            obj.busNames = obj.buildBusNames(hBus);
            obj.traceStep(hPort,'')
            obj.cleanResults();
            obj.validateResults();
            if obj.verbose; obj.dispResults; end;
        end
        
        function cleanResults(obj)
            %% Clean duplicate results
            
            obj.results = unique(obj.results);
            
        end
        
        function dispResults(obj)
            %% Display the results
            fprintf('\nTrace Results:\n\n');
            disp(obj.results);
        end
        
        function validateResults(obj)
            %% Check that each busName had a port
            if ~isempty(obj.busNames)
                for busName = obj.busNames'
                    busName = busName{:}; %#ok<FXSET>
                    if ~any(strmatch(busName,obj.results.BusName))
                        fprintf('Warning: Bus %s for Port %s was not found\n',...
                            busName,obj.hBlock);
                    end
                end
            end
        end
        
    end
end


%% TRACESTEP(pHandle,bussedName)
% Runs a single trace step
% pHandle is a handle for a Port
% bussdName is a string that keeps track of the name in a bus
function traceStep(obj,pHandle,bussedName)

pHandleParent = get_param(pHandle,'Parent');
pHandleName   = get_param(pHandle,'Name');
pHandleType = get_param(pHandle,'Type');
pHandlePortType = get_param(pHandle,'PortType');
pHandleParent(pHandleParent==10) = ' '; % Remove carriage returns
if obj.verbose; fprintf('Tracing %s %s %s %s\n', ...
        pHandleParent, pHandleName, pHandleType, pHandlePortType); end

%% Get the driver/sink port from the port's line
lineH = get_param(pHandle,'Line');

switch obj.tDir
    case 'forward'
        tracePort.H = get_param(lineH,'DstPortHandle');
    case 'backward'
        tracePort.H = get_param(lineH,'SrcPortHandle');
end

if obj.verbose; fprintf('\tTracing line %s %s %s\n', ...
        get_param(lineH,'Parent'),get_param(lineH,'Name'),obj.tDir); end

for h = tracePort.H'
    
    newTracePort.H = h;
    traceHandle(obj,newTracePort,bussedName,lineH)
    
end

end
function traceHandle(obj,tracePort,bussedName,lineH) %#ok<INUSD>

tDir = obj.tDir;
stopBlocks = obj.stopBlocks;

%% Get the parent of the traced driver/sink
tracePort.Num = get_param(tracePort.H,'PortNumber');
tracePort.Type = get_param(tracePort.H,'PortType');

% The parent of the port ( a block
tracePortParent.H     = get_param(tracePort.H,'Parent');
tracePortParent.Type  = get_param(tracePortParent.H,'BlockType');
tracePortParent.Name  = get_param(tracePortParent.H,'Name');
tracePortParent.Ports = get_param(tracePortParent.H,'PortHandles');

% The parent of the parent of the port (a subsystem or the top level diagram)
tracePortParentSystem.H = get_param(tracePortParent.H,'Parent');

%% Determine if the block is a stop block 
%  if it is, add it to the results table
isStopBlock = false;
if any(strcmp(tracePortParent.Type,stopBlocks.type))
    if any(strcmp(tracePortParentSystem.H,stopBlocks.parent))
        isValidBus = any(strcmp(bussedName,obj.busNames));
        if isempty(obj.busNames) || isValidBus;
            isStopBlock = true;
            if obj.verbose
                fprintf('Found stop block: %s\n\tBlock Path: %s\n\tBussedName: %s\n', ...
                    tracePortParent.Name,tracePortParentSystem.H,bussedName);
            end
            hBlock.Name = get_param(obj.hBlock,'Name');
            t = table({hBlock.Name},{tracePortParent.Name},{tracePortParentSystem.H},{bussedName},{tracePortParent.H}, ...
                'VariableNames',{'PortName','ObjectName','ParentName','BusName','Handle'});
            if ~isempty(obj.results)
                obj.results = [obj.results; t];
            else
                obj.results = t;
            end
        end
    end
end


if ~isStopBlock
    %% Determine the next port object to trace
    if obj.verbose; fprintf('\tPort Parent Block Type: %s\n', tracePortParent.Type); end
    switch tracePortParent.Type
        case {'Inport','Outport'}
            %% Search up into a subsystem
            if obj.verbose; fprintf('\tUp %s\n',tracePortParent.H); end
            pType = tracePortParent.Type;
            tracePortParent.Num = get_param(tracePortParent.H,'Port');
            pNum = tracePortParent.Num;
            
            %The handle of the port in the parent subsystem
            tracePortParentSystem.Ports = get_param(tracePortParentSystem.H,'PortHandles');
            ports = tracePortParentSystem.Ports.(pType);
            if isempty(ports)
                error('Something bad happened');
            end
            
            if ischar(pNum)
                pNum = str2double(pNum);
            end
            nextTracePort = ports(pNum);
            
            obj.traceStep(nextTracePort,bussedName)
            
            
        case {'SubSystem'}
            %% Search down into a subsystem
            
            switch tracePort.Type
                case 'outport'
                    bType = 'Outport';
                    pType = 'Inport';
                case 'inport'
                    bType = 'Inport';
                    pType = 'Outport';
            end
            
            if obj.verbose; fprintf('\tDn %s\n',tracePortParent.H); end
            
            nextTraceBlock = find_system(tracePortParent.H,'SearchDepth',1,'FollowLinks','on','BlockType',bType,'Port',num2str(tracePort.Num));
            if isempty(nextTraceBlock)
                error('Something is messed up')
            end
            nextTraceBlock = nextTraceBlock{1};
            
            bPorts = get_param(nextTraceBlock,'PortHandles');
            nextTracePort = bPorts.(pType);
            
            % Run the next step in the trace
            obj.traceStep(nextTracePort,bussedName);
            
        case {'BusCreator','BusSelector'}
            
            switch tDir
                case 'backward'
                    pType = 'Inport';
                case 'forward'
                    pType = 'Outport';
            end
            
            busClass = [tracePortParent.Type '_' tDir];
            
            switch busClass
                case {'BusCreator_forward','BusSelector_backward'}
                    newBusName = trimBusName(bussedName);
                    nextTracePort = tracePortParent.Ports.(pType);
                    obj.traceStep(nextTracePort,newBusName);
                case {'BusCreator_backward','BusSelector_forward'}
                    ports = tracePortParent.Ports.(pType);
                    for p = ports
                        pName = get_param(p,'Name');
                        newBusName = concatBusName(bussedName,pName);
                        nextTracePort = p;
                        obj.traceStep(nextTracePort,newBusName);
                    end
                otherwise
                    error('Something is messed up');
            end
        case {'SignalSpecification','DataTypeConversion'}
            %% Routing blocks
            switch tDir
                case 'backward'
                    pType = 'Inport';
                case 'forward'
                    pType = 'Outport';
            end
            nextTracePort = tracePortParent.Ports.(pType);
            obj.traceStep(nextTracePort,bussedName);
        otherwise
            %% Do nothing, object is not important
            if obj.verbose; fprintf('Done\n'); end
            
    end
end
end

%% Concat two bus names
function name = concatBusName(old, new)
delimeter = '/';
new = regexprep(new,'[<>]','');
name = [old delimeter new];
end

%% Trim the trailing /* off a bus name
function name = trimBusName(name)
name = regexprep(name,'/[\w<>]*$','');
end
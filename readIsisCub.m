function [label, core, isis_version] = readIsisCub(cubfile)
%
%  Copyright 2007-2016  Elliot Sefton-Nash
%
%   Changelog:
%
%     04/11/2007 - ISIS 2 BSQ format implemented.
%     14/01/2009 - ISIS 3 tiled format supported.
%     20/10/2011 - Removes several other characters that are invalid in 
%                  variable names.
%     02/02/2012 - Added the functions get_precision and get_endian to this 
%                  file, since they were previously separate M-files.
%
% A function to read a data file of ISIS cube format.
%   
%   We need to read the header to first determine if this cube is ISIS 3 or
%   ISIS 2 format.
%
%   ISIS 2 cube data is stored in band sequential format, (samples, lines,
%   bands). ISIS 3 cube data may be stored in this format but is by default
%   written in tiled format. The size of an individual tile is denoted in
%   the header:
%
% Object = IsisCube
%   Object = Core
%     StartByte   = 65537
%     Format      = Tile
%     TileSamples = 128
%     TileLines   = 128
%
%   The headers for ISIS2 and ISIS3 cubes differ in that ISIS3 programs
%   produce PDS labels with different values of keywords, objects and
%   groups.
%
%   If an ISIS cube has been processed at some stage by an ISIS 2 program,
%   and at a later stage by an ISIS 3 program, it may still retain a PDS 
%   label in ISIS 2 PVL. 
%   This is stored at the end of the file, after the data cube. 
%   A pointer to it is stored in the header:
% 
% Object = OriginalLabel
%   Name      = IsisCube
%   StartByte = 27590657
%   Bytes     = 3019
% End_Object
%
%
%   'label' is a structure containing, in a hierarchical fashion, all groups,
%   objects and keyword variables containing the values they represent.
%   If the cube file has two labels, at the header and footer then the con-
%   tents of both are placed in 'label'. The structure may then be searched
%   for the keywords required for any given use of the cube.
%   
%   'address' contains the current label.*.*.etc.. address of the structure
%   in which to create new keywords. When we exit a group or object we
%   remove the final stage of the address from the variable i.e. after the
%   final '.'. As a convention, we create all new variables with lower case
%   names.
%
%   First we open the file and loop around a loop reading each line until an
%   'end' line is reached, signifying the end of the header.
%
%   TODO - Loop over all bands if present.

verbose = false;

% 'position' signifies: 0 = end of label - file should be closed 
%                       1 = header label
%                       2 = footer label (EOL)
position = 1;
eoladdress = '';
address = 'label';
isis_version = 0;

fid = fopen(cubfile,'rt');

while (position == 1) || (position == 2)
   
   % Read a line from the file.
   in = fgetl(fid);
   
   % If the line is not null, whitespace or a comment.
   if ~isempty(strtrim(in)) && (isempty(strfind(in, '/*')) && isempty(strfind(in, '*/'))) 
      
       % If the end of the group or object has been reached, come up a level
       % in the label structure.
       if ~isempty(regexpi(in, 'end_group')) || ~isempty(regexpi(in, 'end_object'))
            % Take away the last part of the address, incuding the '.'
            address = address(1:(max(findstr(address, '.')) - 1));
            
       elseif strcmpi(strtrim(in), 'end')

           % If we reach the end of a label.
           if position == 1
                % If there is a group called OriginalLabel
                if ~isempty(eoladdress)
                    % Get the startbyte pointer of the original label and
                    % go to it.
                    eolstartbyte = str2double(eval([eoladdress,'.startbyte']));
                    fseek(fid,eolstartbyte,'bof');
                                 
                    % Set the position to 2, since we are now in the EOL
                    position = 2;
                else
                    % There is not a group called 'OriginalLabel', set position to
                    % false so that the loop is exited and the file is closed.
                    position = 0;
                end
           else 
                % We are in the EOL and have reached the end of the file.
                position = 0;
           end

       % If the input line contains an '=', it must be useful.
       elseif regexp(in, '=')

           % Left hand side is sometimes preceeded by a pipe, |, for some
           % reason. Sometimes an apostrophe (' or char(39)) is also
           % included where double quotes could be used instead.
           % These also confuse things when making variables.
           % - We have to remove/replace these before creating a variable name from the LHS.
           % 
           % So: We trim 'in' from spaces and pipes, replace apostrophes with double quotes, 
           % extract get lhs and rhs, trimming off the '=' and replacing the '^' which we 
           % cannot use as a variable name, with 'hat_'. We also replace
           % colons and semicolons in the variable name with underscores.
           in = strrep(in, '|', '');
           in = strrep(in, char(39), '"');
           [lhs, rhs] = strtok(in,'=');
           rhs = strtrim(strrep(rhs,'= ',''));
           lhs = replace_punct(lhs);
           
           if strcmpi(lhs, 'object') || strcmpi(lhs, 'group')
               
               % If the RHS has punctuation in it that can't be used as a
               % variable name, i.e. a parent in a data structure, then we
               % must replace with something that can (underscore).
               rhs = replace_punct(rhs);
               
               address = [address, '.', lower(rhs)];
               
               % If we have just encountered the group encompassing the
               % original label startbyte, go to it and set the startbyte
               % pointer to it.
               if strcmpi(rhs, 'originallabel')
                   eoladdress = address;
               end
           else
                % If the program is here:
                % 'lhs' contains a keyword, 'rhs' contains the value to be
                % assigned to the keyword. We assign all keywords as
                % strings, we cannot know the data type of each
                % variable. Some numeric PVL numeric variables have units
                % as a suffix, we cannot directly convert these to numeric
                % data types.
               
                % Create the new variable at the current address in the
                % label structure.
                if verbose
                    disp([lower(lhs),' = ', upper(rhs)]);
                end
                eval([address, '.', lower(lhs), '=''', rhs, ''';']);
                
                
                % Set the version here, so that the code beneath knows what
                % parameters to look for when setting file read modes.
                if (isis_version ~= 3)
                    if strcmpi(address, 'label.isiscube.core.dimensions')
                        isis_version = 3;
                    else
                        isis_version = 2;
                    end
                end
                
           end
       end
   end
end

fclose(fid);

% So now we have the location of the data cube and all ancilliary
% information regarding it's format. We may now read it using a method that
% depends on it's format.

% If the format is tiled (ISIS 3), we need to run an entirely different routine
% than if it's BSQ format (generally ISIS 2).

% How do we tell if a cube is an ISIS 3 or ISIS 2 format cube? We test for
% the existance of a variable that is unique to one of the formats. If this
% address exists at any point during the label-reading loop:
%
%               label.isiscube.core.dimensions
%
% then the file must be in ISIS 3 format. This will always exist in ISIS 3 files, since
% there must always be core data. The exist() function does not work for
% checking components of structures. Instead, when reading the labels, an
% 'if' structure sets the variable isis_version = 3 if the address is ever
% equal to the above.
 
switch isis_version
    
    case 2
        % In THEMIS IR images (.QUB), the dimensions are stored in this
        % variable:
        
        dimensions = sscanf(label.qube.core_items, '(%d,%d,%d)');
        samples = dimensions(1);
        lines = dimensions(2);
        bands = dimensions(3);
        data_start_byte = (str2double(label.hat_qube) - 1)*str2double(label.record_bytes);
        
        % Endian is for specifying the read mode to open the file in.
        endian = get_endian(label.qube.core_item_type);
        % Precision is the data type of the core items (pixels).
        precision = get_precision(label.qube.core_item_bytes);    
        
        % Show the size of the overlap and the like...
        if verbose
            disp(['ISIS version = ', num2str(isis_version)]);
            disp('ISIS format is BSQ');
            % disp(['Image dimensions: ', dimensions]);
        end
        
        % OPEN *.cub FILE as binary read-only
        fid = fopen(cubfile, 'r', endian);

        % Skip header
        fseek(fid, data_start_byte, 'bof');

        % Read image data (fread fills column-wise, so must transpose. 
        temp_cub = fread(fid, [samples, lines], precision);
        fclose(fid);
        core = temp_cub';
        
        % Set all null values to zero.
        %core(find(core<0)) = 0.0;
               
    case 3
        % ISIS 3 format
        
        samples = str2double(label.isiscube.core.dimensions.samples);
        lines = str2double(label.isiscube.core.dimensions.lines);
        bands = str2double(label.isiscube.core.dimensions.bands);
        data_start_byte = str2double(label.isiscube.core.startbyte);  % This is the first byte of data, so the file cursor should be set to data_start_byte - 1

        % Endian is for specifying the read mode to open the file in.
        endian = get_endian(label.isiscube.core.pixels.byteorder);
            
        % Precision is the data type of the core items (pixels).
        [precision, pixel_bytes] = get_precision(label.isiscube.core.pixels.type);
               
        if strcmpi(label.isiscube.core.format, 'tile')
        
            % Method to read data from ISIS 3 tiled format, not fully
            % working yet.
            tile_width = str2double(label.isiscube.core.tilesamples);
            tile_height = str2double(label.isiscube.core.tilelines);
            
            x_tiles = ceil(samples / tile_width);
            y_tiles = ceil(lines / tile_height);
                        
            % Region on the edge and base of the image that isn't used, but
            % still held in tiles. In ISIS 3, tile width and height is
            % fixed at 128 pixels - causing the excess.
            x_excess = (x_tiles * tile_width) - samples;
            y_excess = (y_tiles * tile_height) - lines;
            
            % Open file and skip header.
            fid = fopen(cubfile, 'r', endian);
            fseek(fid, data_start_byte - 1, 'bof');
            
            % Set up core data array.
            core = zeros(samples, lines, bands);
            
            % Show the size of the overlap and the like...
            if verbose
                disp(' ');
                disp(['ISIS version = ', num2str(isis_version)]);
                disp(['ISIS format is tiled: ', num2str(tile_width), ' X ', num2str(tile_height)]);
                disp(['Endian: ', endian]);
                disp(['Precision: ', precision, '   , ', num2str(pixel_bytes), ' bytes per pixel.']);
                disp(['Data starts at byte: ', num2str(data_start_byte)]);
                disp(['Image dimensions: ', num2str(size(core))]);
                disp([num2str(x_tiles), ' tiles of width ', num2str(tile_width), ' with an excess of ', num2str(x_excess)]);
                disp([num2str(y_tiles), ' tiles of height ', num2str(tile_height), ' with an excess of ', num2str(y_excess)]);
                disp(' ');
            end
            
            % n will eventually be equal to the number of tiles.
            n = 0;
            for band = 1:bands
                
                for ypos = 1:y_tiles
                    for xpos = 1:x_tiles
                        
                        % Increment tile counter.
                        n = n + 1;
                        
                        % tile_pointer = data_start_byte + (pixel_bytes * n * tile_width * tile_height);
                                                
                        % Set the file cursor to the start of the next
                        % tile.
                        % fseek(fid, tile_pointer, 'bof');
                        current_tile = fread(fid, [tile_width, tile_height], precision)';
                        % 'fread' fills column-wise, so transpose the tile.
                        current_tile = current_tile';
                                                
                        % Lower value coordinate is always the same.
                        core_xpos_lower = ((xpos - 1) * tile_width) + 1;

                        if (xpos * tile_width) > samples

                            if (verbose == 2)
                                disp(['Tile ', num2str(n), ': Trimming - New width = ', num2str(tile_width - x_excess)]); 
                            end

                            % Edge of tile, cut off excess from current_tile
                            core_xpos_upper = ((xpos - 1) * tile_width) + (tile_width - x_excess);
                            current_tile = current_tile(1:(tile_width - x_excess),:);
                        else                     
                            core_xpos_upper = xpos * tile_width;
                        end

                        % Lower value coordinate is always the same.
                        core_ypos_lower = ((ypos - 1) * tile_height) + 1;
                        if (ypos * tile_height) > lines

                            if (verbose == 2)
                                disp(['Tile ', num2str(n), ': Trimming - New height = ', num2str(tile_height - y_excess)]); 
                            end

                            % Edge of tile, cut off excess from current_tile
                            core_ypos_upper = ((ypos - 1) * tile_height) + (tile_height - y_excess);

                            current_tile = current_tile(:,1:(tile_height - y_excess));
                        else
                            core_ypos_upper = ypos * tile_height;
                        end
                        
                        core(core_xpos_lower:core_xpos_upper, core_ypos_lower:core_ypos_upper) = current_tile;
                             
                    end
                end    
            end
                       
            % TODO - 3D cubes: allow for mutliple bands. If only 2D, create
            % a 2D array, stripping the superfluous dimension from it.
            
            % Rotate the image.
            core = core';
            
        elseif strcmpi(label.isiscube.core.format, 'bandsequential')
            
            % The ISIS 3 file is held as band sequential image, so the read
            % method should be the same as for an ISIS 2 cube.
           
            % OPEN *.cub FILE as binary read-only
            fid = fopen(cubfile, 'r', endian);

            % Skip header
            fseek(fid, data_start_byte - 1, 'bof');

            %disp(precision);
            %disp(endian);
            %disp(data_start_byte);
            
            % Read image data (fread fills column-wise, so must transpose. 
            temp_cub = fread(fid, [samples, lines], precision);
            fclose(fid);
            core = temp_cub';

            % Set all null values to zero
            %core(find(core<0)) = 0.0;
  
        else
            disp('ERROR - ISIS 3 file of unknown format.');
        end

    otherwise
        disp('ERROR - Not a recognized ISIS version.');
end

% If the core format is 1 or 2-byte, use base and multiplier
% to convert the core data to meaningful values. If the core format is
% 4-byte (32-bit), the keywords for base and multiplier still exist, but
% have values equal to 0 and 1 respectively, so there is no need to apply
% them.
if strcmpi(precision, 'uint8') || strcmpi(precision, 'int16')
   switch isis_version
       % Get the values of base and mutliplier from wherever they may be
       % held.
       case 2
            base = str2double(label.qube.core_base);
            multiplier = str2double(label.qube.core_multiplier);
            
       case 3
            base = str2double(label.isiscube.core.pixels.base);
            multiplier = str2double(label.isiscube.core.pixels.multiplier);
   end
   core = (core .* multiplier) + base;
end

end

% Function to replace selected punctuation from a string with underscores
% or a descriptive equivalent that can be used as a variable name.
function out = replace_punct(in)

    tmp = strtrim(strrep(in, '^', 'hat_'));
    tmp = strtrim(strrep(tmp, ':', '_'));
    out = strtrim(strrep(tmp, ';', '_'));

end
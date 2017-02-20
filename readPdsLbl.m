function label = readPdsLbl(lblfile)
%
%  Copyright 2008-2016  Elliot Sefton-Nash
%
% A function to read a PDS label file (*.LBL).
%  
%  10/05/2012 - Can deal with multiple 'file' and 'column' groups. Would
%  like to implement a way to deal with any duplicate group, not just
%  specific names.
%
%  11/05/2012 - Now also reads trdrhk.fmt files (from NASA MRO CRISM) 
%  into similar structures.
%  
%  18/05/2012 - Also reads *index.lbl files for *index.tab files. Fixed an
%  issue where the function failed if a parameter contained a single quote.
%
% 'position' signifies: 0 = end of label - file should be closed 
%                       1 = header label
%                       2 = footer label (EOL)

% Check the file exists and is not empty.
s = dir(lblfile);
if ~isempty(s) && s.bytes > 0

    position = 1;
    eoladdress = '';
    address = 'label';
    % isis_version = 0;
    curlyflag = 0;
    doublequoteflag = 0;
    % Sometimes in label files there are object groups for each file referred to,
    % and this is normally more than 1.
    filecounter = 0;
    % Since this rountine can also be used to read the .fmt file (such as e.g. 
    % CRISMs trdrhk.fmt), there are also overlaps with 'column' objects and we 
    % must account for that.
    colcounter = 0;

    fid = fopen(lblfile,'rt');

    while ( (position == 1) || (position == 2) ) && fid ~= -1

       % Read a line from the file.
       in = fgetl(fid);

%      If this line is part of a large field that spans
%      several lines, we add it to the parameter..
       if curlyflag || doublequoteflag 
           eval([address, '.', lower(lhs), '=[',address, '.', lower(lhs), ',in];'])

%          If we find an odd number of double quotes on this line, set
%          flag to zero
           test = numel(strfind(in, char(34)));
           if mod(test,2) == 1
               doublequoteflag = 0;
           end   

%          If we find the closing bracket, set flag to zero
           if strfind(in, '}')
               curlyflag = 0;
           end 

%        Otherwise, if the line is not null or whitespace.
       elseif ~isempty(strtrim(in))
%            If the line does not start with '/*', which indicates it is a
%            comment. We do still allow comments in the same line as a valid
%            parameter=value pair.
           tmp = strtrim(in);
           if ~strcmpi('/*', tmp(1:2))

%                If the end of the group or object has been reached, come up a level
%                in the label structure.
               if ~isempty(regexpi(in, 'end_group')) || ~isempty(regexpi(in, 'end_object'))

%                    Take away the last part of the address, incuding the '.'
                    address = address(1:(max(strfind(address, '.')) - 1));

               elseif strcmpi(strtrim(in), 'end')

%                    If we reach the end of a label.
                   if position == 1
%                         If there is a group called OriginalLabel
                        if ~isempty(eoladdress)
%                             Get the startbyte pointer of the original label and
%                             go to it.
                            eolstartbyte = str2double(eval([eoladdress,'.startbyte']));
                            fseek(fid,eolstartbyte,'bof');

%                             Set the position to 2, since we are now in the EOL
                            position = 2;
                        else
%                             There is not a group called 'OriginalLabel', set position to
%                             false so that the loop is exited and the file is closed.
                            position = 0;
                        end
                   else 
%                         We are in the EOL and have reached the end of the file.
                        position = 0;
                   end

%                If the input line contains an '=', it must be useful    
               elseif regexp(in, '=')

%                    Left hand side is sometimes preceeded by a pipe, |, for some
%                    reason. We have to account for this and remove it before
%                    creating a variable name from the LHS.
%                    Trim 'in' from spaces and pipes, get lhs and rhs, trimming off
%                    the '=' and replacing the '^' which we cannot use as a
%                    variable name, with 'HAT_'.
                   in = strrep(in, '|', '');
                   [lhs, rhs] = strtok(in,'=');
                   lhs = strtrim(lhs);
                   rhs = strtrim(strrep(rhs,'= ',''));

                   if strcmpi(lhs, 'object') || strcmpi(lhs, 'group')
% 
%                        For CRISM MSP labels, there should be groups that refer to
%                        2 files, the .IMG and the .TAB. Knowing that we should be
%                        able to read each one without overwriting the previous
%                        file field in the label structure.
                       if strcmpi(rhs, 'file')
                           filecounter = filecounter + 1;
%                            Rename this group to something hopefully unique by 
%                            suffixing its name with the integer counter.
                           rhs = [rhs, num2str(filecounter)];

                       end

%                        We do the same for 'column' objects when using this
%                        routine for reading PDS .fmt files.
                       if strcmpi(rhs, 'column')
                           colcounter = colcounter + 1;
%                            Rename this group to something hopefully unique by 
%                            suffixing its name with the integer counter.
                           rhs = [rhs, num2str(colcounter)];
                       end

%                        If we have just encountered the group encompassing the
%                        original label startbyte, go to it and set the startbyte
%                        pointer to it.
                       if strcmpi(rhs, 'originallabel')
                           eoladdress = address;
                       end
                       address = [address, '.', lower(rhs)];

                    else
%                         If the program is here:
%                         'lhs' contains a keyword, 'rhs' contains the value to be
%                         assigned to the keyword. We assign all keywords as
%                         strings, we cannot know the data type of each
%                         variable. Some numeric PVL numeric variables have units
%                         as a suffix, we cannot directly convert these to numeric
%                         data types.

%                         Remove and replace invalid characters from the variable name
                        if strfind(lhs, '^')
                            lhs = strrep(lhs, '^', 'hat_');
                        end
                        if strfind(lhs, ':')
                            lhs = strrep(lhs, ':', '_');
                        end

%                         Any single quotes in rhs must be replaced by ''. The
%                         'eval' command will translate this into a single quote
                        if strfind(rhs, '''')
                            rhs = strrep(rhs, '''', '''''');
                        end

%                         Create the new variable at the current address in the
%                         label structure.
                        eval([address, '.', lower(lhs), '=''', rhs, ''';']);

%                         If the value has a '{' at it's beginning and does not
%                         have a corressponding '}' on this line, then we must read
%                         lines until we find a closing curly brace.
                        if ~isempty(strfind(rhs, '{'))
                            if isempty(strfind(rhs, '}'))
                                curlyflag = 1;
                            end
                        end
%                         Similarly, if the rhs has a double quote in it (ASCII 34), we check
%                         to see if this line has an even number of double quotes. If not,
%                         then the rhs spans several lines
                        test = numel(strfind(rhs, char(34)));
                        if mod(test,2) == 1
%                             Odd number of quotes on this line, spans multiple
%                             lines.
                            doublequoteflag = 1;
                        end
                   end  
               end
           end
       end
    end
    fclose(fid);
else
    % If the file is empty or doesn't exist.
    label = -1; 
end

end
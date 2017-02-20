% Function to return the correct precision string for use in fread()
% according to what is read in the PDS label.
%
%  Copyright 2016  Elliot Sefton-Nash
function [precision, pixel_bytes] = getPrecision(pixel_type)

    % Decide on core_item_type, which in ISIS 3 is stored in
    % label.isiscube.core.pixels.type
    switch lower(pixel_type)
        case {'8', '1', 'unsignedbyte', 'unsigned_integer'}
            % 1-byte, UnsignedByte, 8-bit integer, 0 to 255
            precision = '*uint8';
            pixel_bytes = 1;

        case {'16', '2', 'signedword'}
            % 2-byte, SignedWord, 16-bit, -32768 to +32767
            precision = '*int16';
            pixel_bytes = 2;

        case {'32', '4', 'real'}
            % IEEE 32-bit float
            precision = '*float32';
            pixel_bytes = 4;
            
        otherwise
            disp('ERROR - Unrecognized pixel precision.');
    end
end
% Function to return the correct byte-ordering string for use in fopen()
% according to what is read in the PDS label.
%
%  Copyright 2016  Elliot Sefton-Nash
function [endian] = getEndian(data_type)

    % Decide on core_item_type and byte-ordering.
    switch lower(data_type)
        case {'mac_real', 'msb_unsigned_integer', 'msb_integer', 'integer', 'ieee_real', 'real', 'float', 'msb', 'sun_integer', 'sun_real'}
            % Big endian.
            endian = 'ieee-be'; 

        case {'pc_real', 'lsb_integer', 'lsb_unsigned_integer', 'vax_real', 'lsb'}
            % Little endian.
            endian = 'ieee-le'; 

        otherwise
            disp('Unrecognized machine type. Defaulting to Big endian.');
            endian = 'ieee-be';
    end
end
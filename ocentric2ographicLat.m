%
% Function to convert an ographic latitude in degrees to an ocentric one in
% degrees.
%
% ocentricLat - latitude in degrees
% radiusE     - equatorial radius
% radiusP     - polar radius
%
%  Copyright 2016  Elliot Sefton-Nash
function ographicLat = ocentric2ographicLat(ocentricLat,radiusE,radiusP)
    
    % Doesn't correct for phase, just return original if outside bounds.
    if abs(ocentricLat) < 90
        ographicLat = ...
            atand( tand(ocentricLat).*(radiusE/radiusP)^2 );
    else
        ographicLat = ocentricLat;
    end
end
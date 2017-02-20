%
% Convert to lat lon to x and y coordinates in equirectangular.
%
% Inputs:
%   easting  - equirectangular x coordinate
%   northing - equirectangular y coordinate
%   fe       - false easting, allows offset to origin.
%   fn       - false northing
%   r        - planetary radius   
%   lat1     - latitude of standard parallel (latitude of true scale)
%   lonO     - center longitude of projection, origin.
%
%   For Plate Carrée lat1=0 & lon0=0
%
% Outputs:
%   lat,lon
%
%  Copyright 2016  Elliot Sefton-Nash
%
function [lat, lon] = equirec2latlon(easting, northing, fe, fn, r, lat1, lonO)
    lat = rad2deg((northing-fn)/r);
    lon = mod(lonO + rad2deg((easting-fe)/r/cosd(lat1)), 360);
end
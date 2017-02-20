%
% Trim a georeferenced image using the y and x vectors.
% Assumes the image is on a rectangular grid. Note the convention to pass y
% before x, because in Matlab images are stored column-primary (y first).
%
% Author: Elliot Sefton-Nash, 25/05/2009
% 
% Usage:
%  [newimg, newyvec, newxvec] = crop_img(img, yvec, xvec, ylims, xlims)
%
% Where, e.g.
%  xlims = [minx, maxx]
%
function [newimg, newyvec, newxvec] = crop_img(img, yvec, xvec, ylims, xlims)


% If the limits are not set then we don't crop at all. Set the limits to 
% that of the edge of the image.
if isempty(xlims) | xlims == 0
   minx = min(xvec);
   maxx = max(xvec);
else
   minx = min(xlims);
   maxx = max(xlims); 
end
if isempty(ylims) | ylims == 0
   miny = min(yvec);
   maxy = max(yvec);
else
   miny = min(ylims);
   maxy = max(ylims); 
end

newimg = img(((yvec >= miny) & (yvec < maxy)), ((xvec > minx) & (xvec < maxx)));

newyvec = yvec( (yvec >= miny) & (yvec < maxy) );

newxvec = xvec( (xvec >= minx) & (xvec < maxx) );

end
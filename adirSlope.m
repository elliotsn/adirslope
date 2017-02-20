%
% Function to calculate adirectional slope.
%
% Based on algorithm description in:
%
% 'Planetary Terrain Analysis for Robotic missions'
% V. Masarotto, L. Joudrier, J. Hidalgo Carrio, and L. Lorenzoni
% ESA/ESTEC, 2010.
%
% The algorithm assumes that coordinates x, y and z are cartesian and in 
% the same units.
% 
% Inputs:
%
%  z       - 2D array of elevation values for a surface on which to calculate
%            slope.
%  x,y     - arrays of size z containing map-projected coordinates.
%  L       - 'baseline': distance around each pixel at which to calculate the
%            maximum slope.
%  alpha   - angular resolution in degrees at which to search for the 
%            highest values of slope around each pixel.
%  res     - resolution of the DEM, pixel spacing.
%
% Elliot Sefton-Nash 19/12/2016
%
function slp = adirSlope(x, y, z, res, L, alpha)

    s = size(z);
    if ~( (size(x) == size(y)) & (size(y) == s) )
     throwError('x, y and z arrays must be same size.')
    end

    if alpha > 360
     throwError('alpha must be <= 360')
    end
    np = 360/alpha;
    
    if L < res
        warning('L may not be < res. Defaulting baseline to raster resolution.');
        L = res;
    end
    
    ny = s(1);
    nx = s(2);
    
    % Set minimum representable number in double precision to slope.
    slp = repmat(-realmax('double'),s);
    
    [i,j] = meshgrid(1:nx,1:ny);
    % Loop over each direction
    for n = 1:np
                
        % Vectorise: slope in direction n*alpha for all pixels.
        % k,l are vectors of the same length
        
        k = round(i + (L/res)*cosd(n*alpha) );
        l = round(j + (L/res)*sind(n*alpha) );

        % Only within DEM bounds.
        mask = k > 0 & k <= nx & l >= 1 & l <= ny;
        
        % Linear indices of starting pixels in DEM. Note that sub2ind works
        % by [rowNum, colNum] because Matlab is row primary, i.e. goes down
        % y-coordinate first.
        indsStart = sub2ind([ny nx], j(mask),i(mask));
        
        % Linear indices of pixels at baseline in DEM
        indsEnd = sub2ind([ny nx], l(mask),k(mask));

        % Assumes pixel registered DEM. Distance is between pixel
        % centres.
        
        % We require a mask for each pixel.
        dist = sqrt( (x(indsStart) - x(indsEnd)).^2 +...
                     (y(indsStart) - y(indsEnd)).^2 );
        slope = atand( (z(indsStart) - z(indsEnd)) ./ dist );
        
        % Reshape the 1D array of elements concerned in this direction.
        thisSlope = nan(s);
        thisSlope(indsStart) = slope;
        
        % Set new maximum
        newMaxMask = abs(thisSlope) > slp;
        slp(newMaxMask) = abs(thisSlope(newMaxMask));
        
    end
    
    % Any slopes still equal to realmin are set to 0.
    slp(slp == realmin('double')) = 0;
    
end

function throwError(msg)
    error(['adirSlope: ',msg]);
end
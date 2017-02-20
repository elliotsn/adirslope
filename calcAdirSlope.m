
%
% Function to calculate the maximum adirectional slope using a HiRISE
% terrain model and save the results to a Matlab variable file.
%
% Inputs:
%
%  fpath    - full path to the HiRISE DEM, produced by SOCET set and stored
%             in ISIS cub format.
%  outfpath - full path to the variable file that the results should be
%             stored in.
%  L        - 'baseline': distance around each pixel at which to calculate the
%             maximum slope. This can be passed as empty (in which case the
%             native resolution of the DEM is assumed, making it equivalent 
%             to steepest neighbour), a scalar, of a vector of baselines 
%             all to be stored in the same variable file.
%  alpha    - angular resolution in degrees at which to search for the 
%             highest values of slope around each pixel.
%  res      - resolution of the DEM, pixel spacing.
%
% Outputs:
%   success - 1 if successful, 0 if not.
%
%
% Elliot Sefton-Nash 20170213
%  
function success = calcAdirSlope(fpath, outfpath, L, res, alpha)

    try
        % Read the DEM
        d = readHiriseDem(fpath);

        % Make grids of x and y coordinates for adirectional slope algorithm.
        [d.xg, d.yg] = meshgrid(d.xvec, d.yvec);

        % Set defaults for parameters not specified.
        if zeroNanOrEmpty(L) 
            L = d.pixres;
        end
        if zeroNanOrEmpty(res) 
            res = d.pixres;
        end
        if zeroNanOrEmpty(alpha)    
            alpha = 10;
        end

        % Slope for each baseline passed.
        nL = numel(L);
        for il = 1:nL
            Lstr = num2str(L(iL));
            tmp = adirSlope(d.xg, d.yg, d.im, res, L(iL), alpha); %#ok<NASGU>
            % No need for double precision, save some space.
            eval(['slp.L',Lstr,'=single(tmp);']);
        end
        slp.L = L;
        slp.alpha = alpha;
        slp.res = res;
        
        % Don't need to save these large things since they can be built
        % from vectors.
        d = rmfield(d,'xg');
        d = rmfield(d,'yg');
        
        % Similarly, save some space on the DEM too.
        d.im = single(d.im);
        
        % Write results
        save(outfpath, 'slp','d', '-v7.3');
        success = 1;
        
    catch
        success = 0;
        disp(['Unable to calculate slopes for ',fpath]);
    end
end

function b = zeroNanOrEmpty(x)
    if isempty(x)
        b = 1;
        return
    else
        if isnan(x)
            b = 1;
            return
        else
            if x == 0
                b = 1;
                return
            end
        end
    end
    b = 0;
end

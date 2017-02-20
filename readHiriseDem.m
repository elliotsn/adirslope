%
% Function to READ ISIS .cubs - HiRISE and CTX DEMs that are created using 
% Socet Set.
%
function d = readHiriseDem(fpath)

    d.fpath = fpath;
    
    % Read using readIsisCub.
    [d.label, dn, ~] = readIsisCub(fpath);

    % Put core parameters somewhere more easily addressable
    c = d.label.isiscube.core;

    % Set the nodata value based on the ISIS conventions.                    
    % Name                                  32-bit          16-bit	8-bit   Monochrome
    % NULL                                  -3.40282e+38    -32768	0       0
    % Low Representation Saturation (LRS)	-3.40282e+38	-32767	0       black
    % Low Instrument Saturation (LIS)	    -3.40282e+38	-32766	0       black
    % High Instrument Saturation (HIS)   	-3.40282e+38	-32765	255     white
    % High Representation Saturation (HRS)	-3.40282e+38	-32764	255     white
    if isempty(d.label) || isempty(dn)
        msgbox('Unable to read ISIS .cub file.','Warning','warn');
        d = [];
    else
        try
            [~, pixel_bytes] = get_precision(c.pixels.type);    
            switch pixel_bytes
                case 1 % 8 bit
                    null_dn = 0;
                case 2 % 16 bit
                    null_dn = -32768;
                case 4 % 32 bit
                     % This is how the value quoted by the USGS manifests in Matlab.
                    null_dn = -340282265508890445205022487695511781376;
                    % null_dn = -realmax('single'); Almost
                    % the same as the above, but not quite.
                    % Not sure why..
                otherwise
                    null_dn = [];
            end
            if isempty(null_dn)
                % Assume entire core is usable.
                mask = true(size(dn)); %#ok<*PROP>
                % Throw an error to be caught.
                error('');
            else 
                mask = ~(dn == null_dn);  % -3.4028227e+38   -3.4028235e+38
            end
            % Turn null values to NaN.
            dn(~mask) = NaN;
        catch
            % Catches error if the pixel type is not a
            % field in the label structure, or if precision
            % is not in the acceptable list.
            msgbox('Nodata value in .cub file could not be determined, assuming entire raster contains useable data.','Warning','warn');
        end

        % Convert the dn array to science values.
        offset = str2double(c.pixels.base);
        scaling_factor = str2double(c.pixels.multiplier);
        d.im = NaN(size(dn));
        d.im(mask) = (double(dn(mask)) * scaling_factor) + offset;

        % Got data, now get map projection.

        % Map coordinates stored in the 'mapping' group
        % refer to the map-projected values for each pixel.
        % However, the map projection that the cube is
        % stored in may not be the same as the working
        % projection.

        % Raster axes are aligned with map coordinate axes,
        % so vectors of map-projected coordinates may be
        % constructed along each edge. Knowing the
        % projection to lat-lon transformation, lat-lon
        % values are then calculated for each pixel. Which
        % are then converted to the working projection,
        % lambert equal area cylindrical.

        % So far we allow only for the equirectangular
        % projection.

        % Work backwards from label...
        % deg2rad(maximumlatitude)*equatorialradius = 470548.6285221893;
        % upperleftcornery = 470549.30249585;
        % 67.4cm different... curious.

        % Assuming Mars is a sphere of equatorial radius then 
        % deg2rad(minimumlongitude-180) * equatorialradius = 9982352.637996323
        % upperleftcornerx = 9982352.5339656
        % 10.4 cm out, not bad - but not correct.

        % Attempting to account for the polar AND
        % equatorial radii:

        % Radius as a function of latitude: 
        % 
        % f = abs(maximumlatitude)/90;
        % R = f*polarradius + (1-f)*equatorialradius
        % deg2rad(maximumlatitude)*R
        % 470304.3316068953 - 470549.30249585 = -244.9708889547037
        % 245 m out at 7 degrees latitude - much much
        % worse!
        % It's therefore likely that a biaxial ellipsoid is
        % NOT used to calculate the map-projected
        % coordinates. Instead the equatorial radius is
        % probably used, and the few 10s of cm differences
        % have an unknown cause.

        % Make lat-lon for supported projection, allowing for ographic or ocentric lat.

        % Put mapping parameters somewhere more easily
        % addressable.
        m = d.label.isiscube.mapping;

        % Get pixel coordinate vectors
        d.nx = str2double(strRemoveQuotes(c.dimensions.samples));
        d.ny = str2double(strRemoveQuotes(c.dimensions.lines));
        d.pixres = str2double(strRemoveQuotes(strtok(m.pixelresolution)));
        d.ulx = str2double(strRemoveQuotes(strtok(m.upperleftcornerx)));
        d.uly = str2double(strRemoveQuotes(strtok(m.upperleftcornery)));
        % According to: https://isis.astrogeology.usgs.gov/documents/LabelDictionary/LabelDictionary.html
        d.xvec = ((1:d.nx) - 0.5) * d.pixres + d.ulx;
        d.yvec = d.uly - ((1:d.ny) - 0.5) * d.pixres;

        try
            switch lower(m.projectionname)
                case 'equirectangular'
                    
                    d.lonp = str2double(strRemoveQuotes(strtok(m.centerlongitude)));
                    d.latp = str2double(strRemoveQuotes(strtok(m.centerlatitude)));
                    
                    % Get planetary radius at centre latitude.
                    d.re = str2double(strRemoveQuotes(strtok(m.equatorialradius)));
                    d.rp = str2double(strRemoveQuotes(strtok(m.polarradius)));
                    
                    a = d.rp*cosd(d.latp);
                    b = d.re*sind(d.latp);
                    d.r = d.re*d.rp/sqrt(a^2 + b^2);
                    
                    fe = 0;
                    fn = 0;
                    [d.latvec, d.lonvec] = equirec2latlon(d.xvec, d.yvec, fe, fn, d.r, d.latp, d.lonp);
                    
                    % Default lat system is ocentric, convert to ographic if needed.
                    if strfind('ographic',lower(m.latitudetype))
                        d.latvec = ocentric2ographicLat(d.latvec, d.re, d.rp);
                    end

                otherwise
                    msgbox('Unsupported map projection. Data not loaded.','Warning','warn');
            end
        catch
            msgbox('Error reading ISIS cub file. Map projection data not loaded.','Warning','warn');
        end

    end
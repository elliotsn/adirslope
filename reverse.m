% Function to reverse the order of a 1D character array (string).
function [out] = reverse(in)
    temp = in;
    for i = 1:length(in)
        temp(i) = in(length(in) - i + 1);
    end
    out = temp;
end
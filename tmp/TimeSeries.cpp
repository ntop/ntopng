/*
 *
 * (C) 2013-16 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

template <class T> TimeSeries<T>::TimeSeries(u_int32_t _max_datapoints){
    max_datapoints = _max_datapoints;
    num_datapoints = next_datapoint_index = 0;
    xs.reserve(max_datapoints);
    ys.reserve(max_datapoints);
}


template<class T> u_int8_t TimeSeries<T>::addDataPoint(T x, T y){
    if(x != 0 and y != 0)
        ntop->getTrace()->traceEvent(TRACE_DEBUG,
                "Adding datapoint: x=%.2f y=%.2f", x, y);    
    if ((num_datapoints + 1) > max_datapoints) return -1;
    xs[next_datapoint_index] = x;
    ys[next_datapoint_index] = y;
    num_datapoints++;
    next_datapoint_index++;
    return 0;
}

template<class T> double TimeSeries<T>::discreteDerivative(bool normalized){
    if(num_datapoints <= 1)
        numeric_limits<double>::quiet_NaN();  // cannot derive
    double d_sum = 0;
    for (u_int32_t i = 1; i < num_datapoints; i++){
        double d = 0;
        if(xs[i] == xs[i-1]) continue; // prevent zero-division errors
        d = (ys[i] - ys[i-1]) / (xs[i] - xs[i-1]);
        d_sum += d;
        if (d != 0){
            ntop->getTrace()->traceEvent(TRACE_DEBUG,
                    "Deriving: xs[i]=%.2f xs[i-1]=%.2f", xs[i], xs[i-1]);
            ntop->getTrace()->traceEvent(TRACE_DEBUG,
                    "Deriving: ys[i]=%.2f ys[i-1]=%.2f", ys[i], ys[i-1]);
            ntop->getTrace()->traceEvent(TRACE_DEBUG, "Deriving: result %.2f", d);
        }
    }
    // average the derivative
    d_sum /= (double)num_datapoints;
    if (!normalized)
        return d_sum;
    else{
        // obtain the angle theta that the average slopes have with the x-axis
        return atan(d_sum);
    }
}

template class TimeSeries<float>;
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

#ifndef _TIMESERIES_H_
#define _TIMESERIES_H_

template<class T>
class TimeSeries {
private:
    u_int32_t max_datapoints, num_datapoints, next_datapoint_index;
    vector<T> xs;
    vector<T> ys;
public:
    TimeSeries(u_int32_t _max_datapoints);
    u_int8_t addDataPoint(T x, T y);
    double discreteDerivative(bool normalized);
};


#endif /* _TIMESERIES_H_ */


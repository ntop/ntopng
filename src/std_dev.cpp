//
// Created by simone on 12/08/19.
//

#include "std_dev.h"
#include <cmath>

double std_dev::get() {
    return this->n > 0 ? sqrt(this->q / this->n) : 0;
}

void std_dev::new_val(double val) {
    this->n++;
    double tmp = this->mu;
    this->mu = ((this->mu * (this->n - 1)) + val) / this->n;
    this->q = this->q + (val - tmp)*(val - this->mu);
}

std_dev::~std_dev() {

}

std_dev::std_dev() {
    this->n = 0;
    this->mu = 0;
    this->q = 0;
}

#!/usr/bin/env node

const { bignumber, add, subtract, multiply, pow } = require("mathjs")

const buyFYDai = (fyDaiReserves, daiReserves, timeTillMaturity, fyDai, c) => {
    const Y = bignumber(fyDaiReserves)
    const Z = bignumber(daiReserves)
    const T = bignumber(timeTillMaturity)
    const x = bignumber(fyDai)
    const c = bignumber(c)
    const k = bignumber(1/(4 * 365 * 24 * 60 * 60))    // 1 / seconds in four years
    const g = bignumber(950/1000)
    const t = multiply(k, T)
    const a = subtract(1, multiply(g, t))
    const invA = divide(bignumber(1), a)
    const invC = divide(bignumber(1), c)
    const Za = multiply(c, pow(Z, a))
    const Ya = pow(Y, a)
    const Yxa = pow(subtract(Y, x), a)
    const sum = add(multiply(c, Za), multiply(invC, subtract(Ya, Yxa)))
    const y = subtract(multiply(invC, pow(sum, invA)), Z)

    return y
};

const sellVYDai = (fyDaiReserves, daiReserves, timeTillMaturity, vyDai, c) => {
    const Y = bignumber(fyDaiReserves)
    const Z = bignumber(daiReserves)
    const T = bignumber(timeTillMaturity)
    const x = bignumber(dai)
    const c = bignumber(c)
    const k = bignumber(1/(4 * 365 * 24 * 60 * 60))    // 1 / seconds in four years
    const g = bignumber(950/1000)
    const t = multiply(k, T)
    const a = subtract(1, multiply(g, t))
    const invA = divide(bignumber(1), a)
    const Za = multiply(c, pow(multiply(c, Z), a))
    const Ya = pow(Y, a)
    const Zxa = multiply(c, pow(multiply(c, add(Z, x)), a))
    const sum = subtract(add(Za, Ya), Zxa)
    const y = subtract(Y, pow(sum, invA))

    return y
};

const buyVYDai = (fyDaiReserves, daiReserves, timeTillMaturity, vyDai, c) => {
    const Y = bignumber(fyDaiReserves)
    const Z = bignumber(daiReserves)
    const T = bignumber(timeTillMaturity)
    const x = bignumber(dai)
    const c = bignumber(c)
    const k = bignumber(1/(4 * 365 * 24 * 60 * 60))    // 1 / seconds in four years
    const g = bignumber(1000/950)
    const t = multiply(k, T)
    const a = subtract(1, multiply(g, t))
    const invA = divide(bignumber(1), a)
    const Za = multiply(c, pow(multiply(c, Z), a))
    const Ya = pow(Y, a)
    const Zxa = multiply(c, pow(multiply(c, subtract(Z, x)), a))
    const sum = subtract(add(Za, Ya), Zxa)
    const y = subtract(pow(sum, invA), Y)

    return y
};

const sellFYDai = (fyDaiReserves, daiReserves, timeTillMaturity, fyDai, c) => {
    const Y = bignumber(fyDaiReserves)
    const Z = bignumber(daiReserves)
    const T = bignumber(timeTillMaturity)
    const x = bignumber(fyDai)
    const c = bignumber(c)
    const k = bignumber(1/(4 * 365 * 24 * 60 * 60))    // 1 / seconds in four years
    const g = bignumber(1000/950)
    const t = multiply(k, T)
    const a = subtract(1, multiply(g, t))
    const invA = divide(bignumber(1), a)
    const invC = divide(bignumber(1), c)
    const Za = multiply(c, pow(Z, a))
    const Ya = pow(Y, a)
    const Yxa = pow(add(Y, x), a)
    const sum = add(Za, subtract(Ya, Yxa))
    const y = subtract(Z, multiply(invC, pow(sum, invA)))

    return y
};

module.exports = { buyFYDai, sellFYDai, buyDai, sellDai, removeLiquidity }

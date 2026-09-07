use impossible_player::*;
use bellman::groth16::VerifyingKey;
use pairing::bls12_381::{Bls12, Fr};
use pairing::{Field, PrimeField};
use std::fs;

fn rot13(s:&str)->String{s.chars().map(|c|match c{'a'..='z'=>(((c as u8-b'a'+13)%26)+b'a')as char,'A'..='Z'=>(((c as u8-b'A'+13)%26)+b'A')as char,_=>c}).collect()}

fn main() {
    let dec = rot13(&fs::read_to_string("secret").unwrap());
    let mut tau_dec=String::new();
    for l in dec.lines(){ if let Some(v)=l.strip_prefix("TAU="){tau_dec=v.trim().into();} }
    let tau=Fr::from_str(&tau_dec).unwrap();
    let [alpha,beta,gamma,delta,g1s,g2s]=derive(tau);
    let [ic0,ic1]=mint_ic_scalars(tau,alpha,beta,gamma);

    let vkb=fs::read("vk.bin").unwrap();
    let vk=VerifyingKey::<Bls12>::read(&vkb[..]).unwrap();
    println!("ic.len = {}", vk.ic.len());

    let mut abg1s = alpha; // for scaled checks
    let _ = &mut abg1s;

    // helpers
    let mul=|x:Fr,y:Fr|{let mut z=x;z.mul_assign(&y);z};

    println!("alpha_g1 == g1(alpha)          : {}", vk.alpha_g1==g1(alpha));
    println!("alpha_g1 == g1(alpha*g1s)      : {}", vk.alpha_g1==g1(mul(alpha,g1s)));
    println!("beta_g2  == g2(beta)           : {}", vk.beta_g2==g2(beta));
    println!("beta_g2  == g2(beta*g2s)       : {}", vk.beta_g2==g2(mul(beta,g2s)));
    println!("beta_g1  == g1(beta)           : {}", vk.beta_g1==g1(beta));
    println!("beta_g1  == g1(beta*g1s)       : {}", vk.beta_g1==g1(mul(beta,g1s)));
    println!("gamma_g2 == g2(gamma)          : {}", vk.gamma_g2==g2(gamma));
    println!("gamma_g2 == g2(gamma*g2s)      : {}", vk.gamma_g2==g2(mul(gamma,g2s)));
    println!("delta_g2 == g2(delta)          : {}", vk.delta_g2==g2(delta));
    println!("delta_g2 == g2(delta*g2s)      : {}", vk.delta_g2==g2(mul(delta,g2s)));
    println!("delta_g1 == g1(delta)          : {}", vk.delta_g1==g1(delta));
    println!("delta_g1 == g1(delta*g1s)      : {}", vk.delta_g1==g1(mul(delta,g1s)));
    println!("ic[0]    == g1(ic0)            : {}", vk.ic[0]==g1(ic0));
    println!("ic[0]    == g1(ic0*g1s)        : {}", vk.ic[0]==g1(mul(ic0,g1s)));
    println!("ic[1]    == g1(ic1)            : {}", vk.ic[1]==g1(ic1));
    println!("ic[1]    == g1(ic1*g1s)        : {}", vk.ic[1]==g1(mul(ic1,g1s)));
}

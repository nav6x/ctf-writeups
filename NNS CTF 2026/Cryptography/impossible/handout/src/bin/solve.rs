use impossible_player::*;
use bellman::groth16::{Proof as BellmanProof, VerifyingKey};
use pairing::bls12_381::{Bls12, Fr};
use pairing::{Field, PrimeField};
use std::fs;

fn rot13(s:&str)->String{s.chars().map(|c|match c{'a'..='z'=>(((c as u8-b'a'+13)%26)+b'a')as char,'A'..='Z'=>(((c as u8-b'A'+13)%26)+b'A')as char,_=>c}).collect()}

fn main() {
    let dec = rot13(&fs::read_to_string("secret").unwrap());
    let (mut ceremony_id, mut tau_dec) = (String::new(), String::new());
    for l in dec.lines() {
        if let Some(v)=l.strip_prefix("CEREMONY_ID="){ceremony_id=v.trim().into();}
        if let Some(v)=l.strip_prefix("TAU="){tau_dec=v.trim().into();}
    }
    eprintln!("ceremony_id = {}", ceremony_id);
    let tau = Fr::from_str(&tau_dec).unwrap();
    let [alpha,beta,gamma,delta,g1s,g2s] = derive(tau);
    let [ic0,ic1] = mint_ic_scalars(tau,alpha,beta,gamma);

    let mul=|x:Fr,y:Fr|{let mut z=x;z.mul_assign(&y);z};

    let ic_scalar = { let mut t=mul(ic1,fr(CLAIM)); t.add_assign(&ic0); t };

    let a=fr(2); let b=fr(3);
    let ab=mul(a,b);
    let g1g2=mul(g1s,g2s);
    let inner={ let mut t=mul(alpha,beta); let ig=mul(ic_scalar,gamma); t.add_assign(&ig); t };
    let known=mul(g1g2,inner);
    let mut num=ab; num.sub_assign(&known);
    let denom=mul(g2s,delta);
    let mut c=num; c.mul_assign(&denom.inverse().unwrap());

    let proof = Proof{ ceremony_id: ceremony_id.clone(), claim: CLAIM,
        inner: BellmanProof::<Bls12>{ a: g1(a), b: g2(b), c: g1(c) } };

    let vk = VerifyingKey::<Bls12>::read(&fs::read("vk.bin").unwrap()[..]).unwrap();
    let ok = verify(&Public{ceremony_id: ceremony_id.clone(), vk}, &proof);
    eprintln!("local verify = {}", ok);
    assert!(ok, "local verification failed");
    println!("{}", encode_proof(&proof));
}

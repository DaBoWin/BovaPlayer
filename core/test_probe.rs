use bova_probe;

fn main() {
    let info = bova_probe::probe("sample.mp4");
    println!("{}", serde_json::to_string_pretty(&info).unwrap());
}
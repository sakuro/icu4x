use proc_macro::TokenStream;
use quote::quote;
use syn::{DeriveInput, parse_macro_input};

/// Converts a PascalCase identifier to snake_case.
fn to_snake_case(s: &str) -> String {
    let mut result = String::new();
    for (i, c) in s.chars().enumerate() {
        if c.is_uppercase() {
            if i > 0 {
                result.push('_');
            }
            result.push(c.to_ascii_lowercase());
        } else {
            result.push(c);
        }
    }
    result
}

/// Derive macro for converting Ruby symbols to Rust enums.
///
/// # Example
///
/// ```ignore
/// #[derive(FromRubySymbol)]
/// enum RoundingMode {
///     Ceil,       // matches :ceil
///     Floor,      // matches :floor
///     HalfExpand, // matches :half_expand
/// }
/// ```
///
/// This generates:
///
/// ```ignore
/// impl RoundingMode {
///     pub fn from_ruby_symbol(ruby: &magnus::Ruby, sym: magnus::Symbol) -> Result<Self, magnus::Error> {
///         // ... conversion logic
///     }
/// }
/// ```
#[proc_macro_derive(FromRubySymbol)]
pub fn from_ruby_symbol_derive(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);
    let name = &input.ident;

    // Extract enum variants
    let variants = match &input.data {
        syn::Data::Enum(data) => &data.variants,
        _ => panic!("FromRubySymbol can only be derived for enums"),
    };

    // Generate match arms for each variant
    let match_arms = variants.iter().map(|variant| {
        let variant_name = &variant.ident;
        let symbol_name = to_snake_case(&variant_name.to_string());
        quote! {
            if sym.equal(ruby.to_symbol(#symbol_name))? {
                return Ok(Self::#variant_name);
            }
        }
    });

    // Generate list of valid symbol names for error message
    let symbol_names: Vec<String> = variants
        .iter()
        .map(|v| format!(":{}", to_snake_case(&v.ident.to_string())))
        .collect();
    let valid_symbols = symbol_names.join(", ");

    // Generate the impl
    let expanded = quote! {
        impl #name {
            /// Convert a Ruby symbol to this enum type.
            ///
            /// # Arguments
            /// * `ruby` - Ruby runtime reference
            /// * `sym` - The symbol to convert
            /// * `key_name` - The keyword argument name (for error messages)
            ///
            /// # Errors
            /// Returns an error if the symbol doesn't match any variant.
            pub fn from_ruby_symbol(ruby: &magnus::Ruby, sym: magnus::Symbol, key_name: &str) -> Result<Self, magnus::Error> {
                #(#match_arms)*
                Err(magnus::Error::new(
                    ruby.exception_arg_error(),
                    format!("{} must be {}", key_name, #valid_symbols),
                ))
            }
        }
    };

    TokenStream::from(expanded)
}

services=("stackit-otp" "sbi-otp")

echo "Fetching OTP tokens for your services..."
echo "========================================"

# Method 1: Try with default keychain access
echo "Method 1: Default keychain access"
for service in "${services[@]}"; do
    echo "Service: $service"
    token=$(security find-generic-password -a "$service-otp" -w 2>/dev/null | tr -d '\n')
    
    if [ -n "$token" ]; then
        echo "  ✓ Token found: ${token}" # Show first 10 chars for verification
        # Generate OTP if oathtool is available
        if command -v oathtool &> /dev/null; then
            otp_code=$(oathtool --totp -b "$token" 2>/dev/null)
            if [ $? -eq 0 ]; then
                echo "  ✓ OTP Code: $otp_code"
            else
                echo "  ✗ Could not generate OTP (invalid token format?)"
            fi
        else
            echo "  ! Install 'oathtool' to generate OTP codes: brew install oath-toolkit"
        fi
    else
        echo "  ✗ No token retrieved"
    fi
    echo ""
done

import SwiftUI

struct ProfileScreenRouter: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Group {
            if authVM.isLoggedIn {
                ProfileView()
            } else {
                LoginScreen(onSuccess: {
                    authVM.loginSuccessfully()
                })
            }
        }
    }
}

struct ProfileScreenRouter_Previews: PreviewProvider {
    static var previews: some View {
        ProfileScreenRouter()
            .environmentObject(AuthViewModel())
    }
}

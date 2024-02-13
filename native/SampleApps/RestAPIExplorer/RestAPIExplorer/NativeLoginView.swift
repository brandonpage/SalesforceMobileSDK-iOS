//
//  NativeLogin.swift
//  SalesforceSDKCore
//
//  Created by Brandon Page on 12/18/23.
//  Copyright (c) 2023-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import SwiftUI
import SalesforceSDKCore

struct NativeLoginView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isAnimating = false
    var foreverAnimation: Animation {
            Animation.linear(duration: 2.0)
                .repeatForever(autoreverses: false)
        }
    
    init() {

    }
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                if (SalesforceManager.shared.nativeLoginManager().shouldShowBackButton()) {
                    Button {
                        SalesforceManager.shared.nativeLoginManager().cancelAuthentication()
                    } label: {
                        Image(systemName: "arrow.backward")
                            .resizable()
                            .frame(width: 30, height: 30, alignment: .topLeading)
                            .tint(colorScheme == .dark ? .white : .blue)
                            .opacity(0.5)
                    }
                    .frame(width: 30, height: 30, alignment: .topLeading)
                    .padding(.leading)
                    
                } else {
                    Spacer().frame(height: 30)
                }
                Spacer()
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.gray.opacity(0.25))
                    .frame(width: 300, height: 450)
                    .padding(.top, 0)
                
                VStack {
                    Image(.msdkPhone)
                        .resizable()
                        .frame(width: 150, height: 150)
                        .padding(.bottom, 50)
                        .shadow(color: .black, radius: 3)
                        .rotationEffect(Angle(degrees: self.isAnimating ? 360 : 0.0))
                        .animation(self.isAnimating ? foreverAnimation : .default)
                        .blur(radius: 0.0)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .frame(width: 250, height: 50)
                    } else {
                        Spacer().frame(width: 250, height: 65)
                    }
                    
                    ZStack {
                        Text("Username")
                            .foregroundColor(Color(.placeholderText))
                            .offset(x: username.isEmpty ? 0 : -80, y: username.isEmpty ? 0 : -30)
                            .scaleEffect(username.isEmpty ? 1 : 0.6, anchor: .leading)
                            .padding(.top, 25)
                            .frame(maxWidth: 250)
                            .zIndex(2.0)
                        TextField("", text: $username)
                            .foregroundColor(.blue)
                            .disableAutocorrection(true)
                            .multilineTextAlignment(.center)
                            .buttonStyle(.borderless)
                            .autocapitalization(.none)
                            .frame(maxWidth: 250)
                            .padding(.top, 25)
                            .zIndex(2.0)
                    }.animation(.default)
                    
                    ZStack {
                        Text("Password")
                            .foregroundColor(Color(.placeholderText))
                            .offset(x: password.isEmpty ? 0 : -80, y: password.isEmpty ? 0 : -30)
                            .scaleEffect(password.isEmpty ? 1 : 0.6, anchor: .leading)
                            .padding(.bottom)
                            .padding(.top, 10)
                            .frame(maxWidth: 250)
                            .zIndex(2.0)
                        SecureField("", text: $password)
                            .foregroundColor(.blue)
                            .disableAutocorrection(true)
                            .multilineTextAlignment(.center)
                            .buttonStyle(.borderless)
                            .autocapitalization(.none)
                            .frame(maxWidth: 250)
                            .padding(.bottom)
                            .padding(.top, 10)
                            .zIndex(2.0)
                    }.animation(.default)
                    
                        Button {
                            Task {
                                errorMessage = ""
                                self.isAnimating = true
                                let result = await SalesforceManager.shared.nativeLoginManager().login(username: username, password: password)
                                self.isAnimating = false
                                
                                switch result {
                                case .invalidCredentials:
                                    errorMessage = "Please check your username and password."
                                    break
                                case .invalidUsername:
                                    errorMessage = "Username format is incorrect."
                                    break
                                case .invalidPassword:
                                    errorMessage = "Invalid password."
                                    break
                                case .unknownError:
                                    errorMessage = "An unknown error has occurred."
                                    break
                                case .success:
                                    self.password = ""
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "lock")
                                Text("Log In")
                            }.frame(minWidth: 150)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .zIndex(2.0)
                }.padding(.bottom, 0)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.bottom, 125)
            
            Button("Looking for Salesforce Log In?") {
                SalesforceManager.shared.nativeLoginManager().fallbackToWebAuthentication()
            }
        }.background(Gradient(colors: [.blue, .cyan, .green]).opacity(0.6))
            .blur(radius: self.isAnimating ? 2.0 : 0.0)
    }
}

#Preview {
    NativeLoginView()
}
